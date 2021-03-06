# README for LTC with Maven 3

[![Build Status](https://travis-ci.com/SRI-CSL/latextrack.svg?branch=master)](https://travis-ci.com/SRI-CSL/latextrack)

## Requirements

- Java 8 or higher
- git 1.7.2.2 or higher
- Maven 3
- modern LaTeX and fonts; including xelatex and htxelatex (for building manual)

## Developing

Common Maven goals are:

    $> mvn clean
    $> mvn compile
    $> mvn test

To create the distributable:

    $> mvn clean package

To view the contents of a JAR file without expanding it, use Firefox location:
  `jar:file:///Users/linda/git/LTC/all/target/LTC-<version>-SNAPSHOT.jar!/`
and then browse

To perform tests labeled as
`@Category(IntegrationTests.class)`
run goal "verify" (not "integration-test" to allow post integration test phase be run)

To create the site:

    $> mvn verify site

## Deploying 

We are now deploying automatically upon pushing tags.  Do this (for now):

    [ git flow stuff and finally merging with master ]
    $ git checkout master
    $ git push origin master
    $ git tag v1.3 -m "releasing LTC v1.3"
    $ git push origin v1.3
    [... wait for Travis to build and release ~3 minutes, should result in an email ...]
    
## OLD: the site

Before deploying the site, create a shell at sourceforge and delete the current content:

```
+----
$> ssh -t lilalinda,latextrack@shell.sf.net create

Requesting a new shell for "lilalinda" and waiting for it to start.
queued... creating... starting...

This is an interactive shell created for user lilalinda,latextrack.
Use the "timeleft" command to see how much time remains before shutdown.
Use the "shutdown" command to destroy the shell before the time limit.
For path information and login help, type "sf-help".

-bash-3.2$ rm -rf /home/project-web/latextrack/htdocs/*
+----
```

When this has finished and you see the prompt, you are ready to regenerate the information and upload it:

    $> mvn clean verify site site:deploy

When this has finished, go back to your shell and shut it down.  You may look at the uploaded files if you wish:

```
+----
-bash-3.2$ ls -la /home/project-web/latextrack/htdocs/
[...]
-bash-3.2$ shutdown
Requesting that your shell be shut down.
This request will be processed soon.
-bash-3.2$
Broadcast message from root (Wed Dec 12 20:50:46 2012):

The system is going down for system halt NOW!
Connection to shell-24002 closed by remote host.
Connection to shell-24002 closed.
Connection to shell.sf.net closed.
+----
```

## Branching Model

We are now following the ideas behind
* http://nvie.com/posts/a-successful-git-branching-model/

and also start using "git-flow" as explained in
* http://jeffkreeftmeijer.com/2010/why-arent-you-using-git-flow/

We are using the default branch prefixes.  In short, if working on a bigger feature, create a new feature branch from
your current 'develop' branch:

    $> git flow feature start <feature name>
When finishing the bigger feature:

    $> git flow feature finish <feature name>

When you’re feature complete, simply start a release branch — again, based on 'develop' — to bump the version number
and fix the last bugs before releasing:

    $> git flow release start v1.0
    [do minor fixes if needed]
    $> mvn versions:set -DnewVersion=1.0
    $> mvn versions:commit
    $> git commit -am "preparing release of v1.0"
    [in sf.net shell before:]
        rm -rf /home/project-web/latextrack/htdocs/*
        rm -rf /home/frs/project/l/la/latextrack/LTC/1.0
        mkdir /home/frs/project/l/la/latextrack/LTC/1.0
        <copy README.txt?>
    $> mvn clean deploy site site:deploy
    $> git flow release finish v1.0
    [supply tag message]
    $> mvn versions:set -DnewVersion=1.1-SNAPSHOT
    $> mvn versions:commit
    $> git commit -am "bumping next release number to v1.1-SNAPSHOT"

If cutting a release while in the middle of a (larger) feature branch, merge the feature when stable into 'develop'
and then continue the release on develop.  When done, switch back to feature.

    $> git flow feature finish -k FOO
    Checking out files: 100% (22/22), done.
    Switched to branch 'develop'
    ...
    Summary of actions:
    - The feature branch 'feature/FOO' was merged into 'develop'
    - Feature branch 'feature/FOO' is still available
    - You are now on branch 'develop'
    
    $> git st
    # On branch develop
    nothing to commit, working directory clean
    $> git flow release start vX.Y.Z
    Switched to a new branch 'release/vX.Y.Z'
    ...
    [make release and possible more changes on develop]
    $> git flow feature rebase FOO
    Will try to rebase 'FOO'...
    First, rewinding head to replay your work on top of it...
    Fast-forwarded feature/FOO to develop.
etc.

## Running

(after "mvn package")

### Server

  After packaging or wherever you downloaded the JAR:

    $> java -jar all/target/LTC-<version>.jar

  To debug remotely on <PORT> (i.e., when using with Emacs ltc-mode):

    $> java -Xdebug -Xrunjdwp:transport=dt_socket,server=y,suspend=y,address=<PORT> -jar all/target/LTC-<version>.jar

### Java Editor and Viewer

    $> java -cp all/target/LTC-<version>.jar com.sri.ltc.editor.LTCEditor -h
    This editor mimics all functionality of an editor plug-in except it doesn't use XML-RPC to communicate with the
    LTC base system.  Instead, it simply calls the Java methods in the JVM.
    
    $> java -cp all/target/LTC-<version>.jar com.sri.ltc.editor.LTCFileViewer -h
    The file viewer utility by-passes all git specific history and instead allows for a list of files to be
    compared and changes accumulated.  The text is not editable.

### Utilities

 To perform lexical analysis of a .tex file, use either one:

    $> java -cp all/target/LTC-<version>.jar com.sri.ltc.latexdiff.Lexer <FILE>
or
  
    $> cat <FILE> | java -cp all/target/LTC-<version>.jar com.sri.ltc.latexdiff.Lexer

 To compare 2 versions of .tex files, use this utility.  Note that you can trigger XML output using "-x":

    $> java -cp all/target/LTC-<version>.jar com.sri.ltc.latexdiff.LatexDiff -h

 To test the XML-RPC server, use this tool.  You should have the LTC server running:

    $> java -cp all/target/LTC-<version>.jar com.sri.ltc.server.HelloLTC -h

## Testing

For unit tests:

    $> mvn clean test

For integration tests (labeled with IntegrationTests category):

    $> mvn verify

To skip all tests:

    $> mvn verify -Dmaven.test.skip=true

To run an integration test but skip all unit tests, go into the module directory where the test class of interest is
located and do:

    $> mvn -DskipSurefireTests=true -Dit.test=<TEST_CLASS_NAME> verify

To test with different Java versions (on Mac OS X 10.8), e.g. for Java 6:

    $> /usr/libexec/java_home -v 1.6.0 --exec java -jar LTC.jar

## Git Repositories etc.

a) bundling git repositories for download as examples.  See:
  http://stackoverflow.com/questions/2545765/how-can-i-email-someone-a-git-repository
  http://progit.org/2010/03/10/bundles.html

      $> cd independence
      $> git bundle create ../independence.bundle --all
      $> cd $Tutorial
      $> git clone ../LTCmanual/independence.bundle independence

b) retrieving file versions (using first 6 digits of SHA1):

      $> git show <SHA1>:<TEX-FILE> [ > <TEX-FILE>.<SHA1> ]

c) obtaining git tree by hand (for specified file):
  in root of git repository:

      $> git log --topo-order --graph --date=iso8601 \
                 --format=format:"commit %H%nAuthor: %an <%ae>%nDate: %ad%nParents: %P%n%s%n" \
                 <RELATIVE-PATH-TO-TEX-FILE>

d) if extracting 'bundle.git' from a bug report:

      $> git clone report/bundle.git
      Cloning into 'bundle.git'...
      ...
      warning: remote HEAD refers to nonexistent ref, unable to checkout.
      $> cd bundle.git/
      $> git checkout -b master origin/master
      Branch master set up to track remote branch master from origin.
      Already on 'master'

## Building manual by hand

* To build:

$> cd all/src/site/tex/manual
$> xelatex manual  #-shell-escape
or use TeXShop

* To build HTML version by hand:

$> cd all/src/site/tex/manual
$> htxelatex manual "manual,0,png" "" "" "-interaction=nonstopmode --src-specials"

* Converting images using Makefile (and to clean):

$> cd all/src/site/tex/manual/figures
$> make

$> make clean

* To convert manually:

$> cd all/src/site/tex/manual/figures
$> convert -density 150 manual-figure0.pdf manual-figure0.png
or
$> for i in figures/manual-figure*.pdf; do convert -density 150 $i `echo $i | sed -e 's/\.pdf/\.png/g'`; done

$> cd all/src/site/tex/manual/figures
$> for file in *.tiff; do convert $file `basename $file .tiff`.png; done

NOTE: When changing or adding TikZ pictures in the manual, do the following steps:

    $> cd all/src/site/tex/manual
    $> cd figures; make clean; rm -fv manual-figure*; cd ..
    $> cd figures; make; cd ..
    $> xelatex manual --shell-escape
    $> xelatex manual --shell-escape
       # fix makefile: (see: http://stackoverflow.com/questions/5398395/how-can-i-insert-a-tab-character-with-sed-on-os-x)
    $> cat manual.makefile | sed "s/\^\^I/<TAB>/g" > manual.makefile2  # to get TAB character in bash on OS X: Ctrl+V TAB
    $> make -f manual.makefile2
    $> xelatex manual --shell-escape
    $> xelatex manual --shell-escape
    $> cd figures; make; cd ..
    $> htxelatex manual "manual,0,png" "" "" "-interaction=nonstopmode --src-specials"
    $> xelatex manual

## Incrementing version number

Using the Maven versions plugin (https://www.mojohaus.org/versions-maven-plugin/):

    $> mvn versions:display-dependency-updates      => to show, which dependencies have updates
    $> mvn versions:use-latest-versions             => to update all dependencies
    $> mvn versions:display-plugin-updates          => to show, which plugins have updates (still edit by hand?)
    
    $> mvn clean package site                       => to test
    $> mvn versions:commit                          => to remove backup info
    or
    $> mvn versions:revert                          => to use backup info and roll back
    
    $> mvn versions:set -DnewVersion=1.0.2-SNAPSHOT => now updating LTC version information
    $> mvn versions:commit                          => to remove backup info
    or
    $> mvn versions:revert                          => to use backup info and roll back

## License and Copyright information

We use the Maven plugin to update the project license files using:

    $> mvn license:update-project-license

The default Maven lifecycle will manage the copyright statements at the beginning of all source files.

## Programming Emacs mode

Cursor position: C-x =
(note that Emacs starts counting from position 1 but Java document starts from position 0!)

Interactive Emacs Lisp: M-x ielm
- to obtain buffer object for testing:
    ELISP> (setq buf (get-buffer "independence.tex"))
    #<buffer independence.tex>

## Creating SVN repository for tutorial

1. Create local repository and dump

 a) Create svn repository (in your home)

    $> cd
    $> svnadmin create svnrepos

  Now edit svnrepos/conf/svnserve.conf and svnrepos/conf/passwd to contain & start server:

    $> grep -v "^#" svnrepos/conf/svnserve.conf
    
    [general]
    anon-access = none
    auth-access = write
    password-db = passwd
    
    [sasl]
    $> grep -v "^#" svnrepos/conf/passwd
    
    [users]
    franklin = ltc
    adams = ltc
    sherman = ltc
    jefferson = ltc
    $> svnserve -d -r /Users/linda/svnrepos

 b) Fill with first commit

    $> cd ~/tmp/Tutorial
    $> mkdir initial-svn
    $> cd initial-svn
    $> cp ../independence1.tex independence.tex
    $> svn import --username jefferson -m "first version" ~/tmp/Tutorial/initial-svn file:///Users/linda/svnrepos/tutorial-svn
    Adding         /Users/linda/tmp/Tutorial/initial-svn/independence.tex
    
    Committed revision 1.

 c) Checkout and create other versions

      $> cd ~/tmp/Tutorial
      $> svn co --username adams svn://localhost/tutorial-svn
      Authentication realm: <svn://localhost:3690> 8b541c79-ea44-4304-8055-ab4e1cd7933f
      Password for 'adams':
      A    tutorial-svn/independence.tex
      Checked out revision 1.
      $> cp ../independence2.tex independence.tex
      $> svn commit -m "second version" --username adams independence.tex
      Sending        independence.tex
      Transmitting file data .
      Committed revision 2.
      $> svn up
      At revision 2.

  ... and repeat for versions 3 through 6.

      $> svn up
      At revision 6.
      $> svn log -q
      ------------------------------------------------------------------------
      r6 | sherman | 2012-11-13 13:01:00 -0600 (Tue, 13 Nov 2012)
      ------------------------------------------------------------------------
      r5 | sherman | 2012-11-13 13:00:35 -0600 (Tue, 13 Nov 2012)
      ------------------------------------------------------------------------
      r4 | jefferson | 2012-11-13 12:59:45 -0600 (Tue, 13 Nov 2012)
      ------------------------------------------------------------------------
      r3 | franklin | 2012-11-13 12:59:03 -0600 (Tue, 13 Nov 2012)
      ------------------------------------------------------------------------
      r2 | adams | 2012-11-13 12:58:04 -0600 (Tue, 13 Nov 2012)
      ------------------------------------------------------------------------
      r1 | jefferson | 2012-11-13 12:51:35 -0600 (Tue, 13 Nov 2012)
      ------------------------------------------------------------------------

 d) Dump repository into file

    $> cd
    $> svnadmin dump svnrepos > tutorialsvn
    * Dumped revision 0.
    * Dumped revision 1.
    * Dumped revision 2.
    * Dumped revision 3.
    * Dumped revision 4.
    * Dumped revision 5.
    * Dumped revision 6.
    $> gzip -v tutorialsvn
    tutorialsvn:	 77.7% -- replaced with tutorialsvn.gz

2. Replace repository at sf.net (does not work as the non-Classic projects at sf.net don't support this)

[Shell only works in "classic" mode, so setting up a publicly available SVN server]

3. Stop local svnserver

  $> ps axu | grep svn
  linda           2395   0.0  0.0  2433896    408   ??  Ss   12:53PM   0:00.01 svnserve -d -r /Users/linda/svnrepos
  $> kill -9 2395
