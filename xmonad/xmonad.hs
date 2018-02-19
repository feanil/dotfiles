import XMonad
import XMonad.Util.Run
import XMonad.Util.EZConfig(additionalKeys)
import XMonad.Config.Xfce
import XMonad.Hooks.ManageDocks
import System.IO

main = do
     spawnPipe "killall xfce4-panel; xfce4-panel;"
     spawnPipe "synclient MaxTapTime=0"
     spawnPipe "setxkbmap -option 'ctrl:nocaps'"
     xmonad $ xfceConfig 
        { modMask = mod4Mask     -- Rebind Mod to the Windows key
        } `additionalKeys`
	[ ((mod4Mask .|. shiftMask, xK_Return), spawn "xfce4-terminal")
	, ((mod4Mask , xK_p), spawn "rofi -show run")
	]
