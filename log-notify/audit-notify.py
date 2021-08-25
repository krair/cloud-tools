#!/usr/bin/env python3

''' Python based AUDITD plugin to read auditd events and pass them directly to a
matrix room instead of using email or otherwise.

Sources:
https://security-plus-data-science.blogspot.com/2017/06/using-auparse-in-python.html
https://github.com/karmab/audisp-simple/blob/master/audisp-simple.py
'''

import sys
import auparse
import audit
import os
import signal
import logging

logging.basicConfig(level=logging.DEBUG,filename='aunot.log',format='%(asctime)s : %(levelname)s - %(message)s',datefmt='%d-%b-%y %H:%M:%S')
logging.debug("Program begin")

stop = 0
hup = 0
aup = None

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
        logging.info("Begin event writeOut")
        message = "New Event\n------------\n"
        for k,v in self.__dict__.items():
            message += str(k) + " : " + str(v) + "\n"
        message += "====End===="
        logging.debug(f"Message to send: {message}")
        os.execv("/root/matrix-commander/matrix-commander.py",[' ','-m',' ',message])
        logging.info("Message send complete")

def beginParse(aup):
    logging.debug("Begin parser")
    aup.reset()
    event_count = 0
    logging.debug("Audit event reset")
    # Grab each event and parse it out
    while aup.parse_next_event():
        event_count += 1
        logging.debug(f"Event number: {event_count}")
        # Initialize event class with basic data
        event = EventHolder(aup.get_type_name(),aup.get_timestamp())
        logging.info(f"Event created with type: {event.type} and time: {event.time}")
        # If unable to normalize event, write basic info and continue to next event
        if aup.aup_normalize(auparse.NORM_OPT_NO_ATTRS):
            logging.debug(f"Unable to normalize event: {event_count}")
            event.error = "Error normalizing"
            event.writeOut()
            logging.info(f"Non-normalized event info sent: {event_count}")
            continue

        # Catch event kind exception errors
        try:
            event.kind = aup.aup_normalize_get_event_kind()
        except RuntimeError:
            event.kind = "n/a"
            logging.exception("Unable to normalize event kind")

        # TODO - implement whitelist/blacklist filters here?
        if event.kind:
            logging.debug(f"Event kind found as: {event.kind}")
            event.getDetails(aup)

        event.writeOut()
        logging.info("Event Complete\n-----------\n")
    aup = None
    logging.info(f"Log finished. Aup should be 'None': {str(aup)}")

def main():
    global stop
    global hup

    while stop == 0:
        try:
            buf=sys.stdin
            logging.debug("Listening on stdin")
            if hup == 1 :
                reload_config()
                continue
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
