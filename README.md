# GooglePhotos_to_Archieve_Sychroniser

About the project :

As a photography enthusiast, in this project I wanted to use Google Photos API to sync my local archive with it.
As I was already using Google Photos to archieve my all photos ( my own daily family photos.. ) , I was managing all the photos on my local archieve and Google Photos individually on each other.
Then, one day, I just wondered if I can manage my archieve ( delete some unnnecessary photos, copy them to another folder,move etc..) using my Google Photos account.

Ta daaa...

So, here you can find my script to synchronise all your archive with Google Photos.
This script requires Rclone package installed on the machine and you have to configure at least 4 Google Photos API/token to use script.

FEATURES SUPPORTED:

* Copying (WORKS)
* Deleting (WORKS)
* Duplicating (WORKS)
* Moving (WORKS)
* Editing EXIF data (COMING SOON..)

  Basically my script compares all the output taken from Google Photos API with the local archive content folder and trying to find deviations.
  According to deviation analyzes, it makes copy,move,delete actions on local archieve.

  Note: Just to prevent false positive deletions, its moving deleted photos to a JUNKFOLDER.

  On next version, we will be able to manage some empty EXIF data from Google Photos.
  If there is no EXIF information on the photo and if you set it from Google Photos APP, script will understand that as well and make the required changes on the local content.

  At the end of the day, there is no need to manage photos again and again on the local archieve also.
  With just a few clicks on your mobile, ALL IS DONE!

  Kayhan Kaynar
  kayhan.kaynar@hotmail.com
  October, 2023
