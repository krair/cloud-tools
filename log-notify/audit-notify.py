#!/usr/bin/env python3

''' Python based AUDITD plugin to read auditd events and pass them directly to a
matrix room instead of using email or otherwise.

Sources:
https://security-plus-data-science.blogspot.com/2017/06/using-auparse-in-python.html
https://github.com/karmab/audisp-simple/blob/master/audisp-simple.py

Written by: Kit Rairigh - https://rair.dev - https://github.com/krair
'''
# TODO - Group events so a single login is 1 message instead of 4
    # same PID? Session? within 10 second window?
# TODO - add a whitelist option for which events to send: if in WL and NOT in BL
    # TODO - allow for AND/OR statements in blacklist/whitelist
    # TODO - add WL/BL filter earlier in the process?
    # TODO - add timestamp filter in WL/BL
# TODO - config file? For file location of matrix-commander
    # TODO - tear down matrix-commander and incorporate only necessary pieces
# TODO - use tempfile package to securely create tmp logfile,
#   or umask and move to /var/log/audit/

import sys
import auparse
#import audit
#import os
import signal
import logging
import subprocess
import shlex

# Initialize Logging
logging.basicConfig(level=logging.WARN,filename='/tmp/aunot.log',format='%(asctime)s : %(levelname)s - %(message)s',datefmt='%d-%b-%y %H:%M:%S')
logging.debug("Program begin")

# Global vars
stop = 0
hup = 0
aup = None
blacklist = set()

# SIGHUP and SIGTERM handlers
def term_handler(sig, msg):
        global stop
        stop = 1
        logging.info("SIGTERM signal received")
        sys.exit(0)

def hup_handler(sig, msg):
        global hup
        hup = 1
        logging.info("SIGHUP signal received")

def reload_config():
        global hup
        hup = 0
        logging.info("Config reloaded")

signal.signal(signal.SIGHUP, hup_handler)
signal.signal(signal.SIGTERM, term_handler)
logging.debug("Signal handlers initialized")

class EventHolder:
    """ Class to hold event information and send when complete
    """
    def __init__(self,type,time):
        # Initialize with basic information
        self.type = type
        self.time = time

    def getDetails(self,aup):
        """ This section was almost entirely taken from the above listed website.
        As each event in the 'aup' object is not very Python friendly, we must
        follow this odd pattern of deciphering how each piece of information is
        stored.
        """
        # Get session
        if aup.aup_normalize_session():
            self.session = aup.interpret_field()
            logging.debug(f"Session: {self.session}")

        # Get Primary subject - Appears to normally be auid (more verbose?)
        if aup.aup_normalize_subject_primary():
            subPriSub = aup.interpret_field()
            if subPriSub == "unset":
                subPriSub = "system"
            self.primary_subject = subPriSub + " = " + aup.get_field_name()
            logging.debug(f"Primary Subject: {self.primary_subject}")

        # Get secondary subject - Appears to normally be the uid associated
        if aup.aup_normalize_subject_secondary():
            self.secondary_subject = aup.interpret_field() + " = " + aup.get_field_name()
            logging.debug(f"Secondary Subject: {self.secondary_subject}")

        # Get result of action (Success/Failed)
        if aup.find_field("res"):
            self.result = aup.interpret_field()
            logging.debug(f"Result: {self.result}")

        # Get action performed
        try:
            self.action = aup.aup_normalize_get_action()
        except RuntimeError:
            self.action = "n/a"
        logging.debug(f"Action: {self.action}")

        # Get Primary Object
        if aup.aup_normalize_object_primary():
            self.primary_object = aup.get_field_name() + " = " + aup.interpret_field()
            logging.debug(f"Primary Object: {self.primary_object}")

        # Get Secondary Object
        if aup.aup_normalize_object_secondary():
            self.secondary_object = aup.get_field_name() + " = " + aup.interpret_field()
            logging.debug(f"Secondary Object: {self.secondary_object}")

        # Get Object Kind
        try:
            self.object_kind = aup.aup_normalize_object_kind()
        except RuntimeError:
            self.object_kind = "n/a"
        logging.debug(f"Object Kind: {self.object_kind}")

        # Get Binary name (How)
        try:
            self.how = aup.aup_normalize_how()
        except RuntimeError:
            self.how = "n/a"
        logging.debug(f"How: {self.how}")

    def writeOut(self):
        """For lack of a better method, create a long string which will be sent
        to a matrix program called 'matrix-commander'. Trying to import and use
        matrix-commander within this program proved complicated, will revisit.
        The long string is then sent directly to the matrix-commander program.
        Note: The matrix-commander program must already be setup prior to use.
        """
        # Create message, single quotes used to ensure no problems sending
        # TODO - Review if better to use different method to prevent injection
        global blacklist
        logging.info("Begin event writeOut")
        message = "'"
        for k,v in self.__dict__.items():
            # Add blacklist filter
            if (str(k),str(v)) in blacklist:
                logging.info(f"Event found in blacklist, skipping: {k}:{v}")
                return
            message += str(k) + " : " + str(v) + "\n"
        message += "====End===='"
        logging.debug(f"Message to send: {message}")

        # Send via matrix-commander - usually returns exit code 1 even when successful
        try:
            # Location of program, credentials, message store
            cmd = "/usr/sbin/matrix-commander.py -c /usr/local/share/matrix-commander/credentials.json -s /usr/local/share/matrix-commander/store/"
            args = shlex.split(cmd)
            logging.debug(f"Args to send: {args}")
            # Capture as a variable in case I want to return output
            sent = subprocess.run(args, input=message, timeout=10, check=True, capture_output=True, text=True)
            logging.info("Message send completed successfully")
        except subprocess.CalledProcessError:
            # For some reason messages successfully send and still exit code 1
            logging.info(f"Process finished with non-zero code")
        except:
            logging.exception("Message failed")

def beginParse(aup):
    logging.debug("Begin parser")
    aup.reset()
    logging.debug("Audit event reset")
    # Grab each event and parse it out (when using as auditd plugin, generally only 1)
    while aup.parse_next_event():
        # Initialize event class with basic data
        event = EventHolder(aup.get_type_name(),aup.get_timestamp())
        logging.info(f"Event created with type: {event.type} and time: {event.time}")
        # If unable to normalize event, write basic info and continue to next event
        if aup.aup_normalize(auparse.NORM_OPT_NO_ATTRS):
            logging.debug("Unable to normalize event")
            event.error = "Error normalizing"
            event.writeOut()
            continue

        # Catch event kind exception errors
        try:
            event.kind = aup.aup_normalize_get_event_kind()
        except RuntimeError:
            event.kind = "n/a"
            logging.exception("Unable to normalize event kind")

        # Fill in remaining details, might be able to consolidate into getDetails method
        if event.kind:
            logging.debug(f"Event kind found as: {event.kind}")
            event.getDetails(aup)

        # Send completed details to matrix-commander
        event.writeOut()
        logging.info("Event Complete")

    # Clear aup event to minimize memory footprint
    aup = None
    logging.debug(f"AuParse object cleared: {str(aup)}")
    logging.info("Log entry finished. Event cleared.\n----------\n")

def loadBlacklist():
    '''Attempt to load blacklist from file, if unsuccessful, do not use. Events to
    blacklist must be in the form of 'field_name field_value', one per line. Examples
    shown in the blacklist.example file.

    A bit verbose with the True/False return, but included to eventually add Whitelist
    '''
    global blacklist
    try:
        # Load list from file
        with open("/usr/local/share/matrix-commander/blacklist") as bl:
            for line in bl:
                # Ignore commented and blank lines
                if not line.startswith(("#"," ","\n")):
                    i = line.split(" ",1)
                    blacklist.add((i[0],i[1].rstrip()))
        logging.debug(f"Blacklist loaded: {blacklist}")
        return True
    except:
        return False
    if not blacklist:
        return False

def main():
    global stop
    global hup
    if not loadBlacklist():
        logging.error("Failed to load blacklist")

    while stop == 0:
        try:
            buf=sys.stdin
            # Logging event only useful if not working AT ALL. Otherwise causes
            #   huge logfile with infinite loop.
#            logging.debug("Listening on stdin")
            if hup == 1 :
                reload_config()
                continue
            # Start loading lines into our parser
            for line in buf:
                logging.debug(f"Reading line from buffer:\n{line}\n")
                aup = auparse.AuParser(auparse.AUSOURCE_BUFFER, line)
                beginParse(aup)
        except IOError:
            logging.exception("IO Exception occured")
            continue

if  __name__ =='__main__':
        logging.debug("Begin main")
        main()
