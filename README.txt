Deploy Drupal 7 single domain
-----------------------------

Capistrano DEPLOY recipe overrides for managing Drupal 7 single domain instances.

You will probably want to tweek some of the settings and task commands to
meet your server configuration.

Important :
- This recipe was tested using Webistrano only. You can probably use it as a capfile for
  capistrano, but i haven't tested it yet.
- With a small change to the setup task, you can also deploy Drupal 6 websites.
- The recipe assumes you have a working Drush command installed in your host systems.
  The best way to install it is by installing the Drush library in /usr/local/share, then symlinkig
  the Drush executable in /usr/local/bin and putting the drushrc.php in /etc.
  See http://drupal.org/project/drush for details.
  
Don't forget to report all bugs and suggestions back to me so that we can build a real Drupal/Webistrano deployment 
system out of this first recipe sketch.