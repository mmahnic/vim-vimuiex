import os, sys
import ConfigParser
import subprocess as subp

# the directory with vimproject
configdir = os.path.dirname(os.path.abspath(__file__))

# TODO: settings from vimproject/command line;
# paths are relative to configdir
vxprjfile = os.path.abspath(sys.argv[1])
configdir = os.path.dirname(vxprjfile)
filename = os.path.abspath(sys.argv[2])
project = "UNKNOWN.vcxproj"
config = "Debug"
builddir = "Build"
stdafx = ""

cfp = ConfigParser.SafeConfigParser()
cfp.readfp(open(vxprjfile))
section = "plug:msbuild.compile"
if cfp.has_section(section):
    project = cfp.get(section, "project")
    config = cfp.get(section, "config")
    builddir = cfp.get(section, "builddir")
    stdafx = cfp.get(section, "stdafx")
else:
    print "Project: ", vxprjfile
    print "There is no section [" + section + "]"
    print "Aborting"
    sys.exit(1)

if filename.endswith(".h"):
   filename = filename[:-2] + ".cpp"
   filename = filename.replace("/Inc/", "/Src/")

tmpl = """\
:; cmd "/c compile.bat" ; exit # msys
:: Build the solution from the command line
@echo off

setlocal
call vcvars.bat

msbuild "%(project)s" /nologo /t:ClCompile /p:configuration=%(config)s /p:SelectedFiles="%(filenames)s"
if ERRORLEVEL 1 goto builderror

:builderror
"""

if builddir == "":
   builddir = "."

os.chdir(configdir)

fullproject = "%s/%s" % (configdir, project)
fullprjdir = os.path.dirname(fullproject)
fullbuilddir = "%s/%s" % (configdir, builddir)

files = [os.path.relpath(filename, fullprjdir).replace("/", "\\")]
if stdafx != "":
    stdafx = os.path.join(configdir, stdafx)
    files.insert(0, os.path.relpath(stdafx, fullprjdir).replace("/", "\\"))

conf = {
      "project": os.path.relpath(fullproject, configdir).replace("/", "\\"),
      "config": config,
      "filenames": ";".join(files)
      }

script = "%s/compile.bat" % os.path.relpath(fullbuilddir, configdir)
f = open( script, "w" )
f.write( tmpl % conf )
f.close()

os.system(script)
