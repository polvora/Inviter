#Inviter
_I haven't tested this plugin too much, if you see a bug or want to add a new feature you can always create an [issue](https://github.com/polvora/Inviter/issues/new)._

Send Steam group invites from the game chat.

###Client Commands

* `sm_invite [#userid|name]` Sends a Steam group invite to the desired player, if it's used without arguments an invite is sent to the player who invoked it.

### ConVars
####Mandatory
* `in_steamgroupid` ID of the Steam Group where players will be invited, [How to get your group ID](https://support.multiplay.co.uk/support/solutions/articles/1000202859-how-can-i-find-my-steam-group-64-id-)._(default = "")_

#####From SteamCore
* `sc_username` Steam account username.
* `sc_password` Steam account password.

#### Optional
* `in_adminflags` Administrator flags to bypass the restrictions. _(default = "b")_
* `in_allcaninvitethemselves` Allows everybody to send invites to them themselves. _(default = 1)_
* `in_allcaninviteothers` Allows everybody to send invites to other clients. _(default = 0)_
* `in_timebetweeninvites` Time (in seconds) between invites that non-admins must wait before sending another one. _(default = 240)_

### Install
#####Requirements
* [A working version of Sourcemod](http://www.sourcemod.net/downloads.php).
* [SteamCore library plugin](https://github.com/polvora/SteamCore).

_**DON'T FORGET TO SETUP STEAMCORE**_  
When you fulfil the requirements, just install as any other plugin, copy announcer.smx inside the plugins folder in your sourcemod directory.

### Download
Compiled version: [inviter.smx](https://bitbucket.org/Polvora/inviter/downloads/inviter.smx). Also available in downloads section.  

If you want to compile the code yourself you have to add the include file `steamcore.inc` (from SteamCore, duh) inside `scripting/include` and then compile. _(You can't use includes with the online compiler)_

> ###Changelog
> [11/05/2015] v1.0 

> * Initial Release.

> [18/05/2015] v1.1

> * Updated to the new error codes from SteamCore.
