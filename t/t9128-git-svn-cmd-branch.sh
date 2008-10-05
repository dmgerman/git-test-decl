#!/bin/sh
#
# Copyright (c) 2008 Deskin Miller
#

test_description='git svn partial-rebuild tests'
. ./lib-git-svn.sh

test_expect_success 'initialize svnrepo' '
	mkdir import &&
	(
		cd import &&
		mkdir trunk branches tags &&
		cd trunk &&
		echo foo > foo &&
		cd .. &&
		svn import -m "import for git-svn" . "$svnrepo" >/dev/null &&
		cd .. &&
		rm -rf import &&
		svn co "$svnrepo"/trunk trunk &&
		cd trunk &&
		echo bar >> foo &&
		svn ci -m "updated trunk" &&
		cd .. &&
		rm -rf trunk
	)
'

test_expect_success 'import into git' '
	git svn init --stdlayout "$svnrepo" &&
	git svn fetch &&
	git checkout remotes/trunk
'

test_expect_success 'git svn branch tests' '
	git svn branch a &&
	base=$(git rev-parse HEAD:) &&
	test $base = $(git rev-parse remotes/a:) &&
	git svn branch -m "created branch b blah" b &&
	test $base = $(git rev-parse remotes/b:) &&
	test_must_fail git branch -m "no branchname" &&
	git svn branch -n c &&
	test_must_fail git rev-parse remotes/c &&
	test_must_fail git svn branch a &&
	git svn branch -t tag1 &&
	test $base = $(git rev-parse remotes/tags/tag1:) &&
	git svn branch --tag tag2 &&
	test $base = $(git rev-parse remotes/tags/tag2:) &&
	git svn tag tag3 &&
	test $base = $(git rev-parse remotes/tags/tag3:) &&
	git svn tag -m "created tag4 foo" tag4 &&
	test $base = $(git rev-parse remotes/tags/tag4:) &&
	test_must_fail git svn tag -m "no tagname" &&
	git svn tag -n tag5 &&
	test_must_fail git rev-parse remotes/tags/tag5 &&
	test_must_fail git svn tag tag1
'

test_done
