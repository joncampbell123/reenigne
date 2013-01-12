#include "alfe/main.h"
#include "alfe/handle.h"
#include "alfe/email.h"

class Program : public ProgramBase
{
public:
    void response(String status, String title)
    {
        console.write("Status: " + status + "\n"
            "Content-Type: text/html; charset=utf-8'\n\n"
            "<!DOCTYPE html PUBLIC '-//W3C//DTD XHTML 1.0 Strict//EN' "
                "'http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd'>\n"
            "<html xmlns='http://www.w3.org/1999/xhtml' dir='ltr' "
                "lang='en-US'>\n"
                "<head>\n"
                    "<meta http-equiv='Content-Type' content='text/html; "
                        "charset=UTF-8' />\n"
                    "<title>XT Server - " + title + "</title>\n"
                "</head>\n"
                "<body><h1>XT Server</h1>\n");
    }
    void footer()
    {
        console.write("</body>\n"
            "</html>\n");
    }
    void errorPage()
    {
        response("400 Bad Request", "- error");
        console.write("Uh oh - the XT server could not understand your "
            "request. The administrator has been notified, and will fix it "
            "soon if it is our fault.\n");
        footer();

        sendMail("XT Server <xtserver@reenigne.org>",
            "Andrew Jenner <andrew@reenigne.org>", "XT server bad request",
            "Log is " + _logName);
    }
    void run()
    {
        Handle log;
        bool sentHeader = false;
        bool sentPre = false;
        try {
            try {
                bool eof;
                Handle in(GetStdHandle(STD_INPUT_HANDLE));

                // Open a log file
                SYSTEMTIME time;
                GetSystemTime(&time);
                String base = String() + String::Decimal(time.wYear, 4) + 
                    String::Decimal(time.wMonth, 2) + 
                    String::Decimal(time.wDay, 2) + 
                    String::Decimal(time.wHour, 2) + 
                    String::Decimal(time.wMinute, 2) + 
                    String::Decimal(time.wSecond, 2) + 
                    String::Decimal(time.wMilliseconds, 3);
                _logName = base;
                int i = 0;
                do {
                    log = File(_logName).tryOpenWrite();
                    if (log.valid())
                        break;
                    _logName = base + String::Decimal(i);
                    ++i;
                } while (true);

                // Find the boundary delimiter line. It starts with "--".
                String boundary;
                do {
                    // RFC2046: "Boundary delimiters [...] must be no longer
                    // than 70 characters, not counting the two leading
                    // hyphens." If it turns out to be longer, the remaining
                    // characters will fall onto the next line, which will then
                    // fail to parse.
                    boundary = in.readString(&eof, 72);
                    log.write(boundary + "\n");
                    if (eof) {
                        errorPage();
                        return;
                    }
                    if (boundary.length() < 2)
                        continue;
                    if (boundary[0] == '-' && boundary[1] == '-')
                        break;
                } while(true);

                bool gotEmail = false;
                String email;
                bool gotBinary = false;
                String fileName;
                AppendableArray<Byte> data;

                bool formCompleted = false;
                do {
                    // Read a form field
                    String contentDisposition = in.readString(&eof, 58 + 260);
                    log.write(contentDisposition + "\n");
                    if (eof) {
                        errorPage();
                        return;
                    }
                    CharacterSource s(contentDisposition);
                    s.assertString("Content-Disposition: form-data; name=\"");
                    int c = s.get();
                    switch (c) {
                        case 'e':
                            {
                                if (gotEmail) {
                                    errorPage();
                                    return;
                                }
                                gotEmail = true;

                                s.assertString("mail\"");
                                s.assert(-1);

                                String blank = in.readString(&eof, 0);
                                log.write(blank + "\n");
                                if (eof) {
                                    errorPage();
                                    return;
                                }

                                email = in.readString(&eof, 256);
                                log.write(email + "\n");
                                if (eof) {
                                    errorPage();
                                    return;
                                }
                            }
                            break;
                        case 'b':
                            {
                                if (gotBinary) {
                                    errorPage();
                                    return;
                                }
                                gotBinary = true;

                                s.assertString("inary\"; filename=\"");
                                fileName = s.delimitString("\"", &eof);
                                s.assert(-1);

                                String contentType = in.readString(&eof, 38);
                                log.write(contentType + "\n");
                                if (eof) {
                                    errorPage();
                                    return;
                                }
                                if (contentType !=
                                    "Content-Type: application/octet-stream") {
                                    errorPage();
                                    return;
                                }

                                String blank = in.readString(&eof, 0);
                                log.write(blank + "\n");
                                if (eof) {
                                    errorPage();
                                    return;
                                }
                                String dataBoundary = 
                                    String(String::CodePoint(10)) + boundary;
                                do {
                                    int b = in.peekByte(0);
                                    if (b == 13) {
                                        CharacterSource s(dataBoundary);
                                        int dataByte, boundaryByte;
                                        int i = 1;
                                        do {
                                            dataByte = in.peekByte(i);
                                            boundaryByte = s.getByte();
                                            if (boundaryByte == -1) {
                                                log.write(in.read<Byte>());
                                                log.write(in.read<Byte>());
                                                break;
                                            }
                                            ++i;
                                        } while (dataByte == boundaryByte);
                                        if (boundaryByte == -1)
                                            break;
                                    }
                                    if (b == -1) {
                                        errorPage();
                                        return;
                                    }
                                    if (data.count() == 640*1024) {
                                        response("400 Bad Request",
                                            "- file too long");
                                        console.write("The file you sent was "
                                            "too long. 640KB should be enough "
                                            "for anybody.\n");
                                        footer();
                                        return;
                                    }
                                    log.write(in.read<Byte>());
                                    data.append(b);
                                } while (true);
                            }
                            break;
                        default:
                            errorPage();
                            return;
                    }
                    String readBoundary = in.readString(&eof);
                    log.write(readBoundary + "\n");
                    if (eof) {
                        errorPage();
                        return;
                    }
                    s = CharacterSource(readBoundary);
                    if (!s.parseString(boundary)) {
                        errorPage();
                        return;
                    }
                    if (s.parseString("--"))
                        formCompleted = true;
                    if (s.get() != -1) {
                        errorPage();
                        return;
                    }
                } while (!formCompleted);
                if (in.tryReadByte() != -1) {
                    errorPage();
                    return;
                }
                if (!gotEmail || !gotBinary) {
                    errorPage();
                    return;
                }

                AutoHandle h = File("\\\\.\\pipe\\xtserver", true).openPipe();
                h.write<int>(email.length());
                h.write(email);
                h.write<int>(fileName.length());
                h.write(fileName);
                h.write<int>(data.count());
                h.write(data);

                response("200 OK", "- result");
                sentHeader = true;
                console.write("<pre>The XT Server has received your file.\n");
                sentPre = true;
                do {
                    int b = h.tryReadByte();
                    if (b == -1)
                        break;
                    console.write<Byte>(b);
                } while (true);
                console.write(
                    "This concludes your XT server session.</pre>\n");
                footer();
            } catch (Exception& e) {
                if (!sentHeader)
                    response("500 Internal Server Error", " - error");
                else
                    if (sentPre)
                        console.write("</pre>");
                console.write("<p>Uh oh - something went wrong with the XT "
                    "server. The administrator has been notified, and will "
                    "fix it soon.</p>\n");
                footer();

                sendMail("XT Server <xtserver@reenigne.org>",
                    "Andrew Jenner <andrew@reenigne.org>",
                    "XT server exception",
                    "Log is " + _logName + "\n" + "Exception: " + e.message() +
                    "\n");
            }
        }
        catch (Exception& e) {
            log.write(e);
        }
        catch (...) {
            // Don't send the exception back to the user.
        }
    }
private:
    String _logName;
};