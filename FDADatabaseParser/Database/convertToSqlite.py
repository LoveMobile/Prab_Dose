#!/usr/bin/python

DBNAME_BASE = "AndroidFDADatabase"
DBNAME = DBNAME_BASE + ".sqlitedb"
DBNAME_ZIP = DBNAME_BASE + ".zip"

TMPDIR = 'tmp'

import sqlite3
import sys
import os
import glob
import shutil
from subprocess import call

if os.path.exists(DBNAME):
    os.remove(DBNAME)

conn = sqlite3.connect(DBNAME)
c = conn.cursor()

if os.path.exists(TMPDIR):
    shutil.rmtree(TMPDIR)

call(["unzip", "-d", TMPDIR, "Tab-delimited output.zip"])

for tableFilename in glob.glob("tmp/Tab-delimited output/*.txt"):
    tableName = os.path.basename(tableFilename).split(".")[0]

    sys.stdout.write("Processing %s...\n" % (tableName))

    columnNames = None

    for line in open(tableFilename):
        line = line.strip("\n\r")
        colList = line.split("\t")

        if not columnNames:
            columnNames = colList
            createLine = "create table %s (%s)" % (
                tableName,
                ",".join(["%s text" % (colName) for colName in colList]))
            c.execute(createLine)

        else:
            insertLine = "insert into %s values (%s)" % (
                tableName,
                ",".join(['"%s"' % (colVal) for colVal in colList]))
            c.execute(insertLine)

conn.commit()

sys.stdout.write("Creating indexes\n")
c.execute("pragma temp_store=MEMORY")
c.execute("create index Medication_brandName_idx on Medication (brandName ASC)")
c.execute("create index Medication_genericName_idx on Medication (genericName ASC)")
c.execute("create index Medication_medType_idx on Medication (medType ASC)")
conn.commit()

conn.close()


sys.stdout.write("zipping\n")

if os.path.exists(DBNAME_ZIP):
    os.remove(DBNAME_ZIP)
call(["zip", DBNAME_ZIP, DBNAME])

sys.stdout.write("copying\n")

for build in ['client-google', 'client-amazon', 'client-premium-test']:
    dirName = "../../../android/%s/assets/databases/" % (build)
#    call(["mkdir", "-p", dirName])
    call(["cp", DBNAME_ZIP, dirName])

sys.stdout.write("deleting temp dir\n")
shutil.rmtree(TMPDIR)

sys.stdout.write("done\n")
