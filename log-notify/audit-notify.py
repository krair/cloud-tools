#!/usr/bin/env python3

# AUDISP plugin - taken and modified from https://security-plus-data-science.blogspot.com/2017/06/using-auparse-in-python.html

# Python plugin to read auditd events and pass them directly to a matrix room
#   instead of using email or otherwise

import sys
import auparse
import audit
from os import execv #, path
#from tempfile import mkstemp

# TODO - Group events so a single login is 1 message instead of 4
# TODO - Filter event kinds to pass over anything except a login/auth request
    # TODO - add a blacklist/whitelist for which events to send/ignore
# TODO - If there's an error, I don't want 10,000 messages in my inbox (maybe not a problem with the sys.exit(1) call?)
# TODO - config file? For file location of matrix-commander
    # TODO - tear down matrix-commander and incorporate necessary pieces into here

class EventHolder:
    """ Class to hold event information and send when complete
    """
    def __init__(self,type,time):
        # Initialize with basic information
        self.type = type
        self.time = time
        ### To implement when grouping events
        # self.eventExists = False

    def getDetails(self,aup):
        """ This section was almost entirely taken from the above listed website.
        As each event in the 'aup' object is not very Python friendly, we must
        follow this odd pattern of deciphering how each piece of information is
        stored.
        """
        # Get session
        # TODO - What does session represent?
        if aup.aup_normalize_session():
            self.session = aup.interpret_field()

        # Get Primary subject - Appears to normally be auid (more verbose?)
        if aup.aup_normalize_subject_primary():
            subPriSub = aup.interpret_field()
            if subPriSub == "unset":
                subPriSub = "system"
            self.primary_subject = subPriSub + " = " + aup.get_field_name()

        # Get secondary subject - Appears to normally be the uid associated
        if aup.aup_normalize_subject_secondary():
            self.secondary_subject = aup.interpret_field() + " = " + aup.get_field_name()

        # Get result of action (Success/Failed)
        if aup.find_field("res"):
            self.result = aup.interpret_field()

        # Get action performed
        try:
            self.action = aup.aup_normalize_get_action()
        except RuntimeError:
            self.action = "n/a"

        # Get Primary Object
        if aup.aup_normalize_object_primary():
            self.primary_object = aup.get_field_name() + " = " + aup.interpret_field()

        # Get Secondary Object
        if aup.aup_normalize_object_secondary():
            self.secondary_object = aup.get_field_name() + " = " + aup.interpret_field()

        # Get Object Kind
        try:
            self.object_kind = aup.aup_normalize_object_kind()
        except RuntimeError:
            self.object_kind = "n/a"

        # Get Binary name (How)
        try:
            self.how = aup.aup_normalize_how()
        except RuntimeError:
            self.how = "n/a"

    def writeOut(self):
        """For lack of a better method, create a long string which will be sent
        to a matrix program called 'matrix-commander'. Trying to import and use
        matrix-commander within this program proved complicated, will revisit.
        The long string is then sent directly to the matrix-commander program.
        Note: The matrix-commander program must already be setup prior to use.
        """
        message = "New Event\n------------\n"
        for k,v in self.__dict__.items():
            message += str(k) + " : " + str(v) + "\n"
        message += "====End===="
        execv("/root/matrix-commander/matrix-commander.py",[' ','-m',' ',message])
#    def sendToMatrix(self,tmpFile):
#        if path.exists(tmpFile):
#            execl("cat" + tmpFile,"/root/matrix-commander/matrix-commander.py")

# Audit parser initialization (reads from std input - denoted by the "0")
aup = auparse.AuParser(auparse.AUSOURCE_DESCRIPTOR, 0);
# Catch exception
if not aup:
    print("Error initializing AuParser")
    sys.exit(1)

# Grab each event and parse it out
while aup.parse_next_event():
    # Initialize event class with basic data
    event = EventHolder(aup.get_type_name(),aup.get_timestamp())

    # If unable to normalize event, write basic info and continue to next event
    if aup.aup_normalize(auparse.NORM_OPT_NO_ATTRS):
        event.error = "Error normalizing"
        event.writeOut()
        del event
        continue

    # Catch event kind exception errors
    try:
        event.kind = aup.aup_normalize_get_event_kind()
    except RuntimeError:
        event.kind = "n/a"

    # TODO - implement whitelist/blacklist filters here?
    if event.kind:
        event.getDetails(aup)

    event.writeOut()
    del event

aup = None
sys.exit(0)
