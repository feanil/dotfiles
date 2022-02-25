import XMonad
import XMonad.Util.Run
import XMonad.Util.EZConfig(additionalKeys)
import XMonad.Config.Xfce
import System.IO

main = do
     spawnPipe "sleep 2; xfce4-panel -r;"
     spawnPipe "synclient MaxTapTime=0"
     spawnPipe "killall xautolock; xautolock -time 5 -locker 'xdg-screensaver lock';"
     spawnPipe "setxkbmap -option 'ctrl:nocaps'"
     xmonad $ xfceConfig
        { modMask = mod4Mask     -- Rebind Mod to the Windows key
        } `additionalKeys`
        [ ((mod4Mask .|. shiftMask, xK_Return), spawn "xfce4-terminal")
        , ((mod4Mask , xK_p), spawn "rofi -show run")
        , ((mod4Mask .|. shiftMask, xK_l), spawn "xdg-screensaver lock")
        , ((mod4Mask, xK_c), spawn "setxkbmap -option 'ctrl:nocaps'")
        ]
