a = activities()

for (i in a) {
    a[i].wallpaperPlugin    = 'image'
    a[i].wallpaperMode      = 'SingleImage'
    a[i].currentConfigGroup = Array('Wallpaper', 'image')
    a[i].writeConfig('wallpaper', '/usr/share/wallpapers/Tuxedo_10/contents/images/1920x1080.jpg')
    a[i].writeConfig('wallpaperposition', '0')
}