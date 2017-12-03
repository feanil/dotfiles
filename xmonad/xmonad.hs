import XMonad
import XMonad.Util.Run
import XMonad.Util.EZConfig(additionalKeys)
import XMonad.Config.Xfce
import XMonad.Hooks.ManageDocks
import XMonad.Hooks.DynamicLog
import Graphics.X11.ExtraTypes.XF86
import System.IO

main = do
     spawnPipe "synclient MaxTapTime=0"
     spawnPipe "synclient TouchpadOff=1"
     spawnPipe "setxkbmap -option 'ctrl:nocaps'"
     xmonad $ xfceConfig 
        { manageHook = manageDocks <+> manageHook defaultConfig
        , layoutHook = avoidStruts  $  layoutHook defaultConfig
        , modMask = mod4Mask     -- Rebind Mod to the Windows key
        } `additionalKeys`
	[
	]
