
import Graphics.X11.ExtraTypes.XF86
import System.IO

main = do
     spawnPipe "killall trayer; trayer --edge top --align right --width 25 --transparent true --alpha 0 --tint 0 --height 17"
     spawnPipe "killall nm-applet; nm-applet"
     spawnPipe "killall xfce4-volumed; xfce4-volumed"
     spawnPipe "killall xfce4-power-manager; xfce4-power-manager"
     spawnPipe "killall xscreensaver -nosplash; xscreensaver -nosplash"
     spawnPipe "synclient MaxTapTime=0"
     spawnPipe "xloadimage personalize/lotus-wallpaper.jpg -onroot -fullscreen"
     xmproc <- spawnPipe "/usr/bin/xmobar /home/feanil/.config/xmobar/xmobarrc"
     xmonad $ defaultConfig
        { manageHook = manageDocks <+> manageHook defaultConfig
        , layoutHook = avoidStruts  $  layoutHook defaultConfig
        , logHook = dynamicLogWithPP xmobarPP
                        { ppOutput = hPutStrLn xmproc
                        , ppTitle = xmobarColor "green" "" . shorten 50
                        }
        , modMask = mod4Mask     -- Rebind Mod to the Windows key
        } `additionalKeys`
	[
--		, (( 0, xF86XK_MonBrightnessDown  ), spawn "xbacklight -dec 2 && xbacklight |  awk -F. '{ print $1 }' | xargs -I {} notify-send ' ' -R /tmp/displaynotification -i display -h int:value:{}")
--		, (( 0, xF86XK_MonBrightnessUp    ), spawn "xbacklight -inc 2 && xbacklight |  awk -F. '{ print $1 }' | xargs -I {} notify-send ' ' -R /tmp/displaynotification -i display -h int:value:{}")
	]