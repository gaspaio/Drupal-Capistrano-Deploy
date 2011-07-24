# ========================================================================‹
# Deploy Drupal 7 single domain
# ---
# Version::   0.5
# Author::    Rodolfo Ripado  (mailto:ggaspaio@gmail.com)
# Acknowledgements:: Herve Leclerc
#
# Currently supports
# * Setup:: Prepares the a host for deployment creating directories and a local_settings.php
# * Deploy:: Deploy HG tip
# * Rollback:: Return to previous relase, and updates DB to how it was just before the latest release
# =========================================================================


# =============================================
# Script variables. These must be set in client capfile.
# =============================================
_cset(:db_type)         { abort "Please specify the drupal database type" }
_cset(:db_name)         { abort "Please specify the drupal database name" }
_cset(:db_user)         { abort "Please specify the drupal database username" }
_cset(:db_password)     { abort "Please specify the drupal database password" }

# Fixed defaults. Change these at your own risk, (well tested) support for different values is left for future versions.
set :deploy_via,        :remote_cache


# ==============================================
# Defaults. You may change these to your projects convenience
# ==============================================
ssh_options[:verbose] = :debug
_cset :domain,          'default'
_cset :db_host,         'localhost'
_cset :srv_usr,         'www-data'
_cset :srv_password,    'www-data'


# ===============================================
# Script constants. These should not be changed
# ===============================================
set :settings,          'local_settings.php'
set :files,             'files'
set :dbbackups,         'db_backups' 
set :shared_children,   [domain, File.join(domain, files)]        

_cset(:shared_settings) { File.join(shared_path, domain, settings) }
_cset(:shared_files)    { File.join(shared_path, domain, files) }
_cset(:dbbackups_path)  { File.join(deploy_to, dbbackups, domain) }
_cset(:drush)           { "drush -r #{current_path}" + (domain == 'default' ? '' : " -l #{domain}") }

_cset(:release_settings)              { File.join(release_path, 'sites', domain, settings) }
_cset(:release_files)                 { File.join(release_path, 'sites', domain, files) }
_cset(:previous_release_settings)     { releases.length > 1 ? File.join(previous_release, 'sites', domain, settings) : nil }
_cset(:previous_release_files)        { releases.length > 1 ? File.join(previous_release, 'sites', domain, files) : nil }


# =========================================================================
# Overwrites to the DEPLOY tasks in the capistrano library.
# =========================================================================
namespace :deploy do

  desc <<-DESC
    Deploys your Drupal site. It supposes that the Setup task was already executed.
    This overrides the default Capistrano Deploy task to handle database operations and backups,
    all of them via Drush.
  DESC
  task :default do
    update
    update_db
    cleanup
  end


  desc <<-DESC
    Backups the database from the previous and then performs DB update opterations via Drush.
    TODO:: Separate DB backup from DB update tasks so that the later can be called standalone.
  DESC
  task :update_db, :except => { :no_release => true } do
    #Backup the previous release's database 
    if previous_release
      run "#{drush} sql-dump > #{ File.join(dbbackups_path, "#{releases[-2]}.sql") }"
    end

    #Update current DB 
    run <<-CMD
      #{drush} fra -y &&
      #{drush} cc all &&
      #{drush} updatedb -y
    CMD
  end


  desc <<-DESC
    Prepares one or more servers for deployment.
    Creates the necessary file structure and the shared Drupal settings file.
  DESC
  task :setup, :except => { :no_release => true } do
    #Create shared directories
    dirs = [deploy_to, releases_path, shared_path, dbbackups_path]
    dirs += shared_children.map { |d| File.join(shared_path, d) }
    run <<-CMD
      mkdir -p #{dirs.join(' ')} &&
      #{try_sudo} chown www-data:www-data #{shared_files}
    CMD

    #create drupal config file
    configuration = <<EOF
<?php
  $databases = array ('default' => array ('default' => array (
        'database' => '#{db_name}',
        'username' => '#{db_user}',
        'password' => '#{db_password}',
        'host' => '#{db_host}',
        'port' => '',
        'driver' => '#{db_type}',
        'prefix' => '',
  )));
EOF
    put configuration, shared_settings
  end


  desc "Rebuild files and settings symlinks"
  task :finalize_update, :except => { :no_release => true } do
    run <<-CMD
      ln -nfs #{shared_files} #{release_files} &&
      ln -nfs #{shared_settings} #{release_settings}
    CMD

    if previous_release
      run <<-CMD
        rm -f #{previous_release_settings} &&
        rm -f #{previous_release_files}
      CMD
    end 
  end


  desc <<-DESC
    Removes old releases and corresponding DB backups.
  DESC
  task :cleanup, :except => { :no_release => true } do
    count = fetch(:keep_releases, 5).to_i
    if count >= releases.length
      logger.important "No old releases to clean up"
    else
      logger.info "keeping #{count} of #{releases.length} deployed releases"
      old_releases = (releases - releases.last(count))
      directories = old_releases.map { |release| File.join(releases_path, release) }.join(" ")
      databases = old_releases.map { |release| File.join(dbbackups_path, "#{release}.sql") }.join(" ")

      run "rm -rf #{directories} #{databases}"
    end
  end


  namespace :rollback do  
  
    desc <<-DESC
    [internal] Points the current, files, and settings symlinks at the previous revision.
    DESC
    task :revision, :except => { :no_release => true } do
      if previous_release
        run <<-CMD
          rm #{current_path};
          ln -s #{previous_release} #{current_path};
          ln -nfs #{shared_files} #{previous_release_files};
          ln -nfs #{shared_settings} #{previous_release_settings}
        CMD
      else
        abort "could not rollback the code because there is no prior release"
      end
    end


    desc <<-DESC
    [internal] If a database backup from the previous release is found, dump the current
    database and import the backup. This task should NEVER be called standalone.
    DESC
    task :db_rollback, :except => { :no_release => true } do
      if previous_release
        logger.info "Dumping current database and importing previous one (If one is found)."
        previous_db = File.join(dbbackups_path, "#{releases[-2]}.sql")
        import_cmd = "#{drush} sql-drop -y && #{drush} sql-cli < #{previous_db} && rm #{previous_db}"
        run "if [ -e #{previous_db} ]; then #{import_cmd}; fi"
      else
        abort "could not rollback the database because there is no prior release db backups"
      end
    end

    task :default do
      revision
      db_rollback
      cleanup
    end

  end

  # Each of the following tasks are Rails specific. They're removed.
  task :migrate do
  end

  task :migrations do
  end

  task :cold do
  end

  task :start do
  end

  task :stop do
  end

  task :restart do
  end

end