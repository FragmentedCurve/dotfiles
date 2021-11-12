# dotfiles

As the name implies, this script is a tool for managing your dotfiles.

## Concept

Let your dotfiles live where they want and records their changes. Only
selected dotfiles are tracked for changes. If you track a directory,
that directory is watched for new files.

When a change or new file is found, the change is pulled into the git
repository.

## Setup

Fork or clone this repository.

    shell> cd ~/git/
    shell> git clone https://github.com/FragmentedCurve/dotfiles.git

I recommend setting an alias for the `dotfiles.sh` script.

    shell> alias dotfiles=~/git/dotfiles/dotfiles.sh

In addition to the alias, I recommend creating a branch other than the
main (or master) branch for tracking dotfiles.

    shell> dotfiles git checkout -b mybranch

## Tracking dotfiles

Tracking a dotfile is as easy as doing,

    shell> dotfiles track .muttrc
    ::: COPY     _muttrc

The filename `.muttrc` is relative to `~/`. Filenames in the git repo
have their "." replaced with an "_". You can list the files being
tracked by doing,

    shell> dotfiles ls
    _muttrc

To watch for new files in a specific directory, you can track the
directory,

    shell> dotfiles track ~/.mutt
    ::: MKDIR    _mutt
    ::: WATCH    _mutt

Now when we do a **pull**, new files in ~/.mutt will be tracked
automatically.

    shell> touch ~/.mutt/foobar
    shell> dotfiles pull
    ::: COPY     _mutt/foobar

We can see the directories we're watching by doing,

    shell> dotfiles watching
    _mutt

## Checking the Diffs

If you want to see what the difference between your system dotfile and
the git repo, you can do,

    shell> dotfiles diff .muttrc
    --- _muttrc     2021-11-12 09:51:06.443690988 -0500
    +++ /home/user/.muttrc  2021-11-12 10:00:52.937004607 -0500
    @@ -55,3 +55,4 @@
    #### Fetch Mail
    macro generic,index,pager G "<shell-escape>mbsync privateemail<Enter>" "offlineimap"
    macro generic,index,pager I "<shell-escape>imapfilter<Enter>" "imapfilter"
    +# Foobar

Running `dotfiles diff` without an arg will loop through all the
changes.
