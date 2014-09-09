# vim: set fileencoding=utf-8 sw=4 sts=4 ts=8 et :vim

import os, sys, re

# Supported masks
# *        any file in root directory; alt: /* TODO
# **       any file; alt: *
# *.c      any .c file in root directory; alt: /*.c TODO
# **/*.c   any .c file; alt: *.c
# -*.c     exclude .c files in root directory TODO
# -dir/    skip directory root/dir TODO
# dir/yes/ add directory root/dir/yes TODO
# -**/dir/ skip any directory named dir
class CFileFilter:
    def __init__(self, name, basedir=None):
        self.name = name
        self.references = []
        self.filesFound = []
        self.basedir = basedir
        self.basedirIncluded = False
        self._dirTests = []
        self._fileTests = []
        self.defaultAcceptFile = False

    def clear(self):
        self.references = []
        self._dirTests = []
        self._fileTests = []

    def addReference(self, name):
        self.references.append(name)

    def addCondition(self, mask):
        mask = mask.strip()
        binclude = True
        bdirmask = mask.endswith("/")
        if mask.startswith("-"):
            mask = mask[1:]
            binclude = False
        elif mask.startswith("+"):
            mask = mask[1:]
            binclude = True
        if mask == None or mask == "":
            return
        if self.name == "[ignore]":
            binclude = False
        regmask = mask.replace(".", "\\.")
        regmask = regmask.replace("**", "\x01\x01") # XXX: this may still fail
        regmask = regmask.replace("*", "[^/]*")
        regmask = regmask.replace("\x01\x01", ".*")
        regmask = regmask.replace("?", "[^/]")

        if bdirmask: self._addDirCondition(regmask[:-1], binclude)
        else: self._addFileCondition(regmask, binclude)

    # TODO: conditions anchored at root are not matched (eg. *.c).
    # We need a new set of conditions for every root.
    def _addFileCondition(self, regex, included):
        full = re.compile("^%s$" % regex, re.IGNORECASE)
        self._fileTests.append( (full, included) )

    # TODO: conditions anchored at root are not matched (eg. *.c).
    # We need a new set of conditions for every root.
    def _addDirCondition(self, regex, included):
        full = re.compile("^%s$" % regex, re.IGNORECASE)
        partial = re.compile("^(%s)/" % regex, re.IGNORECASE)
        self._dirTests.append( (full, partial, included) )


    # Normal dirs are accepted by default. Links are not accepted by default.
    # If a directory is fully matched by a mask, it's inclusion changes as
    # defined by the mask.  If a directory is partially matched, the length of
    # the match must be greater than the length of a previous partial match, if
    # any.  This enables the test to prune a subdirectory but still add its
    # subdirectory to the list.
    def dirAccepted(self, fname, islink):
        accept = not islink
        partlen = 0
        for full, partial, included in self._dirTests:
            if included == accept:
                continue
            mo = full.match(fname)
            if mo != None:
                accept = included
                continue
            mo = partial.match(fname)
            if mo != None:
                if len(mo.group(1)) > partlen:
                    partlen = len(mo.group(1))
                    accept = included
        return accept

    # Files are not accepted by default
    def fileAccepted(self, fname):
        accept = self.defaultAcceptFile
        for full, included in self._fileTests:
            if included == accept:
                continue
            mo = full.match(fname)
            if mo != None:
                accept = included
                continue
        return accept


class CFinder:
    def __init__(self, basedir):
        self.basedir = basedir
        self.sections = []
        self.ignore = []

    def reorderSections(self):
        for s in self.sections:
            if s.name == "[ignore]":
                self.sections.remove( s )
                self.ignore.append( s )
                s.references = []
                s.defaultAcceptFile = True
                break

    def configure(self, lineiter):
        class InternalSection:
            def __init__(self): self.name = None
        internal = InternalSection()
        section = None
        defaultBaseDir = self.basedir
        for line in lineiter:
            line=line.strip()
            if line == "" or line.startswith("#"):
                continue
            if line.startswith("["):
                if section != None:
                    self.sections.append(section)
                if line == "[include]" or line == "[includes]":
                    section = None
                elif line == "[subproject]" or line == "[subprojects]":
                    section = None
                elif line == "[ignore]":
                    section = CFileFilter(line)
                elif line == "[vimproject]":
                    section = internal
                    section.name = line
                else:
                    section = CFileFilter(line)
                continue
            if section == None:
                continue

            if section == internal:
                print "internal"
                if line.startswith("basedir="):
                    pass
                continue

            if line.startswith("basedir="):
                pass
            elif line.startswith("@"):
                section.addReference(line)
            else:
                section.addCondition(line)

        self.reorderSections()

    # distribute files into sections
    def _classifyFiles(self, root, files):
        badfiles = set([])
        for sec in self.ignore:
            accept = sec.dirAccepted(root, islink=False)
            if not accept: return
            for f in files:
                ff = "%s/%s" % (root, f)
                accept = sec.fileAccepted(ff)
                if not accept:
                    badfiles.add( f )
        # print badfiles
        files = [ "%s/%s" % (root, f) for f in files if f not in badfiles ]

        for sec in self.sections:
            accept = sec.dirAccepted(root, islink=False)
            if not accept: continue
            for ff in files:
                accept = sec.fileAccepted(ff)
                if not accept: continue
                sec.filesFound.append(ff)

    # All paths are converted to "/" form.
    # In pass 1 the normal directories are processed.
    # In pass 2 the explicitly named symlinked directories are processed.
    def processFiles(self):
        roots = [self.basedir] # TODO: unhandled roots from sections with 'basedir='
        links = []
        # pass 1
        for basedir in roots:
            for root, dirs, files in os.walk(basedir):
                rd = root.replace("\\", "/")
                self._classifyFiles(rd, files)

                # find dir-links to process in 2nd pass
                for d in dirs:
                    dd = "%s/%s" % (rd, d)
                    if os.path.islink(dd):
                        for sec in self.sections:
                            accept = sec.dirAccepted(dd, islink=True)
                            if accept:
                                links.append(dd)
                                break

        # pass 2
        for basedir in links:
            for root, dirs, files in os.walk(basedir):
                rd = root.replace("\\", "/")
                self._classifyFiles(rd, files)

    def dump(self, writer):
        for sec in self.sections:
            writer.write(sec.name)
            writer.write("\n")
            for t in sec._dirTests:
                writer.write("d: %s  %s  %s\n" % (t[0].pattern, t[1].pattern, t[2]))
            for t in sec._fileTests:
                writer.write("f: %s  %s\n" % (t[0].pattern, t[1]))
            for f in sec.filesFound:
                writer.write(f)
                writer.write("\n")
            for r in sec.references:
                writer.write(r)
                writer.write("\n")

    def writeResults(self, writer):
        for sec in self.sections:
            writer.write(sec.name)
            writer.write("\n")
            for f in sec.filesFound:
                writer.write(f)
                writer.write("\n")
            for r in sec.references:
                writer.write(r)
                writer.write("\n")

def testExample(filename):
    filename = os.path.abspath(filename)
    finder = CFinder(os.path.dirname(filename))
    f = open(filename)
    finder.configure(f)
    f.close()
    finder.processFiles()
    finder.dump(CWriter())

def process(filename):
    filename = os.path.abspath(filename)
    finder = CFinder(os.path.dirname(filename))
    f = open(filename)
    finder.configure(f)
    f.close()
    finder.processFiles()
    finder.writeResults(sys.stdout)

if __name__ == "__main__":
    # print "/", sys.argv[1]
    process(sys.argv[1])
