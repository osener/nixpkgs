#! @perl@ -w

use strict;
use Cwd 'abs_path';
use IO::Handle;
use File::Path;
use File::Basename;
use JSON::PP;

STDOUT->autoflush(1);

my $out = $ENV{"out"};

my @pathsToLink = split ' ', $ENV{"pathsToLink"};

sub isInPathsToLink {
    my $path = shift;
    $path = "/" if $path eq "";
    foreach my $elem (@pathsToLink) {
        return 1 if
            $elem eq "/" ||
            (substr($path, 0, length($elem)) eq $elem
             && (($path eq $elem) || (substr($path, length($elem), 1) eq "/")));
    }
    return 0;
}


# For each activated package, determine what symlinks to create.

my %symlinks;

for my $p (@pathsToLink) {
    $p = "" if $p eq "/";
    $symlinks{$p} = ["", 0];
}

sub findFiles;

sub findFilesInDir {
    my ($relName, $target, $ignoreCollisions, $priority) = @_;

    opendir DIR, "$target" or die "cannot open `$target': $!";
    my @names = readdir DIR or die;
    closedir DIR;

    foreach my $name (@names) {
        next if $name eq "." || $name eq "..";
        findFiles("$relName/$name", "$target/$name", $name, $ignoreCollisions, $priority);
    }
}

sub findFiles {
    my ($relName, $target, $baseName, $ignoreCollisions, $priority) = @_;

    # Urgh, hacky...
    return if
        $relName eq "/propagated-build-inputs" ||
        $relName eq "/nix-support" ||
        $relName =~ /info\/dir/ ||
        ( $relName =~ /^\/share\/mime\// && !( $relName =~ /^\/share\/mime\/packages/ ) ) ||
        $baseName eq "perllocal.pod" ||
        $baseName eq "log";

    my ($oldTarget, $oldPriority) = @{$symlinks{$relName} // [undef, undef]};

    # If target doesn't exist, create it. If it already exists as a
    # symlink to a file (not a directory) in a lower-priority package,
    # overwrite it.
    if (!defined $oldTarget || ($priority < $oldPriority && ($oldTarget ne "" && ! -d $oldTarget))) {
        $symlinks{$relName} = [$target, $priority];
        return;
    }

    # If target already exists as a symlink to a file (not a
    # directory) in a higher-priority package, skip.
    if (defined $oldTarget && $priority > $oldPriority && $oldTarget ne "" && ! -d $oldTarget) {
        return;
    }

    unless (-d $target && ($oldTarget eq "" || -d $oldTarget)) {
        if ($ignoreCollisions) {
            warn "collision between `$target' and `$oldTarget'\n" if $ignoreCollisions == 1;
            return;
        } else {
            die "collision between `$target' and `$oldTarget'\n";
        }
    }

    findFilesInDir($relName, $oldTarget, $ignoreCollisions, $oldPriority) unless $oldTarget eq "";
    findFilesInDir($relName, $target, $ignoreCollisions, $priority);

    $symlinks{$relName} = ["", $priority]; # denotes directory
}


my %done;
my %postponed;

sub addPkg {
    my ($pkgDir, $ignoreCollisions, $priority)  = @_;

    return if (defined $done{$pkgDir});
    $done{$pkgDir} = 1;

    findFiles("", $pkgDir, "", $ignoreCollisions, $priority);

    my $propagatedFN = "$pkgDir/nix-support/propagated-user-env-packages";
    if (-e $propagatedFN) {
        open PROP, "<$propagatedFN" or die;
        my $propagated = <PROP>;
        close PROP;
        my @propagated = split ' ', $propagated;
        foreach my $p (@propagated) {
            $postponed{$p} = 1 unless defined $done{$p};
        }
    }
}

# Read packages list.
my $pkgs;

if (exists $ENV{"pkgsPath"}) {
    open FILE, $ENV{"pkgsPath"};
    $pkgs = <FILE>;
    close FILE;
} else {
    $pkgs = $ENV{"pkgs"}
}

# Symlink to the packages that have been installed explicitly by the
# user.
for my $pkg (@{decode_json $pkgs}) {
    for my $path (@{$pkg->{paths}}) {
        addPkg($path, $ENV{"ignoreCollisions"} eq "1", $pkg->{priority}) if -e $path;
    }
}


# Symlink to the packages that have been "propagated" by packages
# installed by the user (i.e., package X declares that it wants Y
# installed as well).  We do these later because they have a lower
# priority in case of collisions.
my $priorityCounter = 1000; # don't care about collisions
while (scalar(keys %postponed) > 0) {
    my @pkgDirs = keys %postponed;
    %postponed = ();
    foreach my $pkgDir (sort @pkgDirs) {
        addPkg($pkgDir, 2, $priorityCounter++);
    }
}


# Create the symlinks.
my $extraPrefix = $ENV{"extraPrefix"};
my $nrLinks = 0;
foreach my $relName (sort keys %symlinks) {
    my ($target, $priority) = @{$symlinks{$relName}};
    my $abs = "$out" . "$extraPrefix" . "/$relName";
    next unless isInPathsToLink $relName;
    if ($target eq "") {
        #print "creating directory $relName\n";
        mkpath $abs or die "cannot create directory `$abs': $!";
    } else {
        #print "creating symlink $relName to $target\n";
        symlink $target, $abs ||
            die "error creating link `$abs': $!";
        $nrLinks++;
    }
}


print STDERR "created $nrLinks symlinks in user environment\n";


my $manifest = $ENV{"manifest"};
if ($manifest) {
    symlink($manifest, "$out/manifest") or die "cannot create manifest";
}
