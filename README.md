# local_users

<!-- vim-markdown-toc GFM -->

* [Description](#description)
* [Setup](#setup)
  * [What local_users affects](#what-local_users-affects)
  * [Setup Requirements](#setup-requirements)
  * [Beginning with local_users](#beginning-with-local_users)
* [Usage](#usage)
  * [Adding SSH Keys](#adding-ssh-keys)
  * [Adding Users](#adding-users)
  * [Adding Groups](#adding-groups)
  * [Removing Users](#removing-users)
  * [Removing Groups](#removing-groups)
  * [Defining named sets of users](#defining-named-sets-of-users)
* [Reference](#reference)
  * [Adding SSH Keys](#adding-ssh-keys-1)
  * [Adding Users](#adding-users-1)
    * [Updating file permssions](#updating-file-permssions)
    * [Password expiry](#password-expiry)
  * [Adding Groups](#adding-groups-1)
  * [Removing Users](#removing-users-1)
  * [Removing Groups](#removing-groups-1)
* [Issues](#issues)

<!-- vim-markdown-toc -->

## Description
Puppet module to easily manage local users and their authorized keys.  It also manages local groups. It's an abstraction layer over the user and group resources to make it easier to add/remove users/groups across different systems using just hiera and calling this class.

Features:
  * reads password hashes and SSH public keys from HashiCorp Vault
  * sets the password aging for non expiring accounts
  * generates a series of accounts (e.g. for testing purposes)

It makes some assumptions to simplify the creation of local users:
  * the GID is the same as the UID unless it is explicitly specified
  * if GID is not specified, the system will choose one
  * the home directory location is the convention for the OS - it will be created if it doesn't exist

It will fail, if:
  * there is no user comment (GECOS) (unless the user is `root`)

It is designed to be driven by hiera, not so much through code.

## Setup

### What local_users affects

  * `/etc/passwd`, `/etc/shadow` and `/etc/group` mostly through the Puppet user and group resources, but does use the low level commands in certain circumstances.
  * user home directories
  * users' authorized keys
  * permissions of files in users' home directories may be updated to match a new UID and/or GID (but only if explicity enabled)

### Setup Requirements
  * The stdlib module
  * The `sshkeys_core` module
  * The `vault_msi` module, with its Puppet Server Vault agent and CLI configured
  * It does presume there is a basic system perl installed on systems being managed

### Beginning with local_users

Include the class in your code:
```
  class { 'local_users': }
```

Create the `puppet/local_users` KV secret in Vault. Password hashes are named
`<username>_hash`. Each public key name starts with `<username>_pubkey`; this may
be the complete name or be followed by any text. The complete Vault field name
becomes the `ssh_authorized_key` resource title. Public-key values use the
normal OpenSSH public-key format:

```
jblogs_hash: '$6$...'
jblogs_pubkey: 'ssh-ed25519 AAAAC3... jblogs@workstation'
jblogs_pubkeyjblogs-yubikey: 'ssh-rsa AAAAB3... jblogs@yubikey'
```

Define any groups that will be required for the users.  Also delete some unnecessary groups or ignore some groups 
(i.e. don't remove them even if they are specified for removal in a more general scope, but they also don't need to 
be fully defined through the 'add' data).

```
local_users::add::groups:
  admin: {}
  git:
    gid: 15002

local_users::remove::groups:
  - thesmiths
  - builders

local_users::ignore::groups:
  - ftp
  - root

```

Define some users and their groups. Vault entries are associated automatically
by username. Also, delete some redundant users or ignore others
(i.e. don't remove them even if they are specified for removal in a more general scope, but they also don't need to 
be fully defined through the 'add' data).


```
local_users::add::users:
  jblogs:
    uid: 1000
    comment: Joe Blogs
    expiry: none
    groups: ['a','b','c']
  bsmith:
    uid: 1051
    comment: Bill Smith
    expiry: none
    mode: '0700'
  bsmith0:
    uid: 1052
    comment: Bill Smith 0
    mode: '0700'
    generate: 10
  root:
    expiry: none

local_users::remove::users:
  - jsmith
  - bob

local_users::remove::sysusers:
  - games
  - shutdown

local_users::ignore::users:
  - ftp
  - root

```

**Important**

The `local_users::remove::sysusers` collection will not try to remove the home directory regardless of the global `managehome` setting.  If a system
user is specified for removal in `local_users::remove::users` and `managehome` is also set to `true` then the home directory will be removed (or attempted 
at least) - e.g. `/root`, `/sbin`, etc. - which will corrupt your systems! (i.e. delete critical binaries).

## Usage

### Adding SSH Keys

Add each key to the `puppet/local_users` Vault secret. The exact
`<username>_pubkey` name and any name beginning with that prefix are accepted,
so an optional suffix can distinguish multiple keys. The complete Vault field
name is used as the `ssh_authorized_key` resource title. The value must contain
an OpenSSH key type and base64 key; a trailing comment is optional.

```
jblogs_pubkey: 'ssh-ed25519 AAAAC3... jblogs@workstation'
```

### Adding Users

Add users by defining hashes/Data in the hiera data:

```
local_users::add::users:
  jblogs:
    uid: 1000
    comment: Joe Blogs
    expiry: none
```

If Vault contains `jblogs_hash`, that hash is assigned as the user's password.
If it contains one or more entries beginning with `jblogs_pubkey`, all are
installed in the user's `authorized_keys` file.

### Adding Groups

Add groups by defining hashes/Data in the hiera data.  If the group hash is empty, then the system will decide the GID,
otherwise it can be specified.

```
local_users::add::groups:
  admin: {}
  git:
    gid: 15002
```

### Removing Users

Simply provide a list of groups to the hiera key:

```
local_users::remove::users: []
```

### Removing Groups

Simply provide a list of groups to the hiera key:

```
local_users::remove::groups: []
```

### Defining named sets of users

You can define named sets of users in your hiera data and refer to those sets when adding users to nodes.
This way, you do not need to update hiera or manifest files in many locations when people or
responsibilities change.

Here's some example hiera data that defines a database of users and their properties under the key
`local_users::staff`. Then, it makes named sets under the keys `local_users::department::developers` and
`local_users::department::sysadmins`. Note that these keys have no particular meaning to the
`local_users` module on their own, so at this point, we've simply defined some data:
```yaml
# common.yaml or similar
local_users::staff:
  mbaynton:
    uid: 100
    gid: 13779
    comment: Mike Baynton
  user2:
    uid: 1234
    gid: 13779
    comment: Another user
  thirdUser:
    uid: 4567
    gid: 13779
    comment: A third user

local_users::department::developers:
  mbaynton: '%{alias("local_users::staff.mbaynton")}'
  user2: '%{alias("local_users::staff.user2")}'
local_users::department::sysadmins:
  thirdUser: '%{alias("local_users::staff.thirdUser")}'
```

Now we can apply our named sets to nodes as desired by assigning them to the `local_users::add::users` key (which
_does_ have special meaning to the `local_users` module):
```yaml
# node1.my.org.yaml or similar
local_users::add::users:
  - '%{alias("local_users::department::developers")}'
  - '%{alias("local_users::department::sysadmins")}'
```

This concept can even be extended to create named sets that contain nested named sets.

## Reference

### Adding SSH Keys

SSH keys are loaded from `puppet/local_users` using
`vault_msi::kv_get('puppet/local_users')`. See [Adding SSH Keys](#adding-ssh-keys).

### Adding Users

`local_users::add::users`

Requires a hash of user definition hashes.  

Each user definition hash must have a comment field (except root), otherwise system defaults will prevail.  
All Puppet user resource fields except `password` are supported, plus these additional ones:
  * `mode` - the mode of the home directory
  * `base_dir` - the directory where the user's home directory with be created within
  * `generate` - the number of similar users to create.  I.e. 10 wil create 10 users.  Each user will be numbered sequentially and if the UID is specified, it will also be incremented.

The `password` and legacy `auth_keys` properties are ignored. Passwords and SSH
keys are selected from Vault using each resulting username, including usernames
created with `generate`.

If the GID of the user does not correspond to an existing group, a new one will be created named after the user. 

If an existing group has the same name but a different GID then Puppet will throw an error saying it is unable to match the group.  This can be fixed by setting `local_users::add::force_group_gid_fix`
to `true` - this will change the GID of the group matching the name with the required GID.  This is not enabled by default.

#### Updating file permssions

When `local_users::add::fix_file_perms` is set to `true` and the UID/GID of the user is changing, any files in the home directory of the user matching the old UID/GID will be updated to the new UID/GID.
This is **not** enabled by default.

If the GID of the user has been specified as a name rather than ID and the GID of that group is being changed by Puppet, the GID of the files in the home directory will not be changed as it is 
impossible to capture this scenario without re-doing the built-in user resource.

#### Password expiry

Setting an account expiry to `none` will tune the `expiry` and `password_max_age` for each OS nuance to give expected 
behaviour.  This doesn't always work as expected out of the box with Puppet.

### Adding Groups

Groups behave the same as the Puppet group resource.

### Removing Users

All users specified for removal will be forcefully removed - i.e. all running processes belonging to that user will be killed
before the removal is attempted.

### Removing Groups
Groups being removed will simply be removed with the Puppet group resource.

## Issues
Only tested on UNIX/Linux type systems.  It does require a working perl 5, but only the core modules.  I don't always have access to AIX, so sometimes it breaks.

Since version 1.0.1 of this module duplicate GIDs will not be forced through.  This will create an issue if you have previously relied on this behaviour.

Since version 1.1.0 it requires Puppet 4 and above (hiera functions were replaced with lookup) and internal hiera was converted to version 5
