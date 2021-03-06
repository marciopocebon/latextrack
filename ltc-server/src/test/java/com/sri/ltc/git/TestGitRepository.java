/*
 * #%L
 * LaTeX Track Changes (LTC) allows collaborators on a version-controlled LaTeX writing project to view and query changes in the .tex documents.
 * %%
 * Copyright (C) 2009 - 2012 SRI International
 * %%
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as
 * published by the Free Software Foundation, either version 3 of the 
 * License, or (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public 
 * License along with this program.  If not, see
 * <http://www.gnu.org/licenses/gpl-3.0.html>.
 * #L%
 */
package com.sri.ltc.git;

import com.sri.ltc.Utils;
import com.sri.ltc.categories.IntegrationTests;
import com.sri.ltc.versioncontrol.Commit;
import com.sri.ltc.versioncontrol.RepositoryFactory;
import com.sri.ltc.versioncontrol.TrackedFile;
import com.sri.ltc.versioncontrol.VersionControlException;
import org.junit.Rule;
import org.junit.Test;
import org.junit.experimental.categories.Category;

import java.io.BufferedReader;
import java.io.File;
import java.io.IOException;
import java.util.List;

import static org.junit.Assert.*;

@Category(IntegrationTests.class)
public class TestGitRepository {

    // a fresh repository for each test:
    @Rule
    public TemporaryGitRepository temporaryGitRepository = new TemporaryGitRepository();

    @Test
    public void testUntracked() {
        assertTrue(temporaryGitRepository.getRoot().exists());

        try {
            TrackedFile trackedFile = temporaryGitRepository.createTestFileInRepository("foo", ".txt", "testUntracked", false);
            assertTrue(trackedFile.getStatus() == TrackedFile.Status.NotTracked);
        } catch (Exception e) {
            fail(e.getMessage());
        }
    }

    @Test
    public void testAddAndCommit() {
        assertTrue(temporaryGitRepository.getRoot().exists());

        try {
            TrackedFile trackedFile = temporaryGitRepository.createTestFileInRepository("foo", ".txt", "testAddAndCommit", true);
            assertEquals("Status is ADDED", TrackedFile.Status.Added, trackedFile.getStatus());

            trackedFile.commit("commit from testAddAndCommit");
            assertEquals("Status is UNCHANGED", TrackedFile.Status.Unchanged, trackedFile.getStatus());
        } catch (Exception e) {
            fail(e.getMessage());
        }
    }

    @Test
    public void testAddCommitAndModify() {
        assertTrue(temporaryGitRepository.getRoot().exists());

        try {
            TrackedFile trackedFile = temporaryGitRepository.createTestFileInRepository("foo", ".txt", "testAddCommitAndModify", true);
            assertEquals("Status is ADDED", TrackedFile.Status.Added, trackedFile.getStatus());

            trackedFile.commit("commit A from testAddCommitAndModify");
            assertEquals("Status is UNCHANGED", TrackedFile.Status.Unchanged, trackedFile.getStatus());

            {
                // create a different file, so we can verify that we get commits only for the file we do care about
                TrackedFile garbageFile = temporaryGitRepository.createTestFileInRepository("garbage", ".txt", "testAddCommitAndModify - not the file we care about", true);
                garbageFile.commit("commit garbage file from testAddCommitAndModify");
            }

            System.out.println("Getting commits for " + trackedFile.getFile().getPath());
            List<Commit> commits;
            commits = trackedFile.getCommits();
            assertTrue(commits.size() == 1);
            assertTrue(commits.get(0).getMessage().equals("commit A from testAddCommitAndModify"));

            temporaryGitRepository.modifyTestFileInRepository(trackedFile, "modification", true);
            assertEquals("Status is MODIFIED", TrackedFile.Status.Modified, trackedFile.getStatus());

            trackedFile.commit("commit B from testAddCommitAndModify");

            System.out.println("Getting commits (after modification) for " + trackedFile.getFile().getPath());
            commits = trackedFile.getCommits();
            assertTrue(commits.size() == 2);
        } catch (Exception e) {
            fail(e.getMessage());
        }
    }

    @Test
    public void testMultifileCommit() {
        // the idea here is to make sure that when more than one file is modified at a time,
        // and we commit, we commit just the file we mean to.
        assertTrue(temporaryGitRepository.getRoot().exists());

        try {
            TrackedFile trackedFile0 = temporaryGitRepository.createTestFileInRepository("file0", ".txt", "file0 contents", true);
            TrackedFile trackedFile1 = temporaryGitRepository.createTestFileInRepository("file1", ".txt", "file1 contents", true);
            TrackedFile trackedFile2 = temporaryGitRepository.createTestFileInRepository("file2", ".txt", "file2 contents", true);

            trackedFile1.commit("Three file modify, one file commit from testMultifileCommit");

            {
                List<Commit> commits = trackedFile0.getCommits();
                assertTrue(commits.size() == 0);
            }

            {
                List<Commit> commits = trackedFile1.getCommits();
                Commit file1Commmit = commits.get(0);

                BufferedReader reader = new BufferedReader(file1Commmit.getContents());
                String line = reader.readLine();
                assertTrue(line.equals("file1 contents"));
            }

            {
                List<Commit> commits = trackedFile2.getCommits();
                assertTrue(commits.size() == 0);
            }
        } catch (Exception e) {
            fail(e.getMessage());
        }
    }

    @Test
    public void badThingsWithRepo() throws VersionControlException, IOException {
        // do bad things to repo such as removing .git or the whole tree...

        assertTrue(temporaryGitRepository.getRoot().exists());
        TrackedFile trackedFile = null;
        List<Commit> commits = null;

        try {
            // commit a few revisions
            trackedFile = temporaryGitRepository.createTestFileInRepository("foo", ".txt", "first version of file", true);
            assertEquals("tracked file is added", TrackedFile.Status.Added, trackedFile.getStatus());
            trackedFile.commit("commit A from badThingsWithRepo");
            temporaryGitRepository.modifyTestFileInRepository(trackedFile, "\n more text into file", true);
            assertEquals("tracked file is modified", TrackedFile.Status.Modified, trackedFile.getStatus());
            trackedFile.commit("commit B from badThingsWithRepo");

            // getting commits works
            commits = trackedFile.getCommits();
            assertEquals("2 commits", 2, commits.size());

            // checking out file structure
            assertTrue("root is directory", temporaryGitRepository.getRoot().isDirectory());
            File[] gitDir = temporaryGitRepository.getRoot().listFiles(RepositoryFactory.GIT_FILTER);
            assertTrue(".git exists", gitDir != null);
            assertEquals("only 1 .git exists", 1, gitDir.length);

            // now doing bad things...
            assertTrue(".git is directory", gitDir[0].isDirectory());
            Utils.deleteFolder(gitDir[0]);
            assertTrue("second deletion doesn't work", !gitDir[0].delete());
        } catch (Exception e) {
            fail(e.getMessage());
        }

        assert trackedFile != null;
        commits = trackedFile.getCommits();
        assertEquals("no commits", 0, commits.size());
    }
}
