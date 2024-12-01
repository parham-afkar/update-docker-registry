Updating and synchronizing Docker registry images and re-pushing images

option 1: you must provide an image:tag.  
If the image:tag exists in the registry, it will be updated and if the image does not exist, it will be pulled and then pushed.  
option 2: all images in the registry will be updated.
