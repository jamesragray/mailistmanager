import std.stdio;
import std.file;
import std.algorithm;
import std.range;
import std.datetime;
import std.uuid;
import std.format;
import std.process;
import vibe.vibe;

auto hostName = "localhost:8080";
auto emailsFile = "emails.lst";
string[] emails;

void main() {
	if(emailsFile.exists) {
		emails = File(emailsFile).byLineCopy.array;
	}
	auto settings = new HTTPServerSettings;
	settings.port = 8080;
	settings.bindAddresses = ["::1", "127.0.0.1"];
	auto router = new URLRouter;
	router.get("/",&hello);
	router.post("/add",&addEmailHandler);
	router.post("/remove",&removeEmailHandler);
	router.get("/action/:uid",&doActionHandler);
	auto listener = listenHTTP(settings, router);
	scope (exit) { listener.stopListening(); }
	logInfo("Please open http://127.0.0.1:8080/ in your browser.");
	runApplication();
}


void removeEmail(string email) {
	foreach(i,e; emails) {
		if(e==email) {
			emails = emails[0..i] ~ emails[i+1..$];
			break;
		}
	}
	writeList;
}

void addEmail(string email) {
	foreach(i,e; emails) {
		if(e==email) { return; } //Don't allow multiple same email.
	}
	emails~=email;
	writeList;
}

void writeList() {
	std.file.write(emailsFile,format("%-(%s\n%)",emails));
}

auto genUniqueString() {
	return randomUUID().toString ~  Clock.currTime.toISOString;
}

void sendEmail(string adr, string msg) {
	 string cmd = format(`
	 echo "%s" | ./emailer -s "Stellenbosch mathematics mailing list" -f "james@gray.net.za" -t "%s" -r "smtp://gray.net.za"`,msg,adr);
	executeShell(cmd);
}

void delegate()[string] actions;

void addEmailHandler(HTTPServerRequest req, HTTPServerResponse res) {
	auto email = req.form.get("emailAddress","");
	email.writeln;
	string uniqueString = genUniqueString;
	actions[uniqueString] = (){
		addEmail(email);
	};
	sendEmail(email, format(`
This email address was entered to be added to the Stellenbosch mathematics colloquium mailing list.
Please ignore this message if you do not want to be added.
Please enter the following link in your browser to be added:
http://%s/action/%s
`,hostName,uniqueString));
	res.redirect("/");
}
void removeEmailHandler(HTTPServerRequest req, HTTPServerResponse res) {
	auto email = req.form.get("emailAddress","");
	email.writeln;
	string uniqueString = genUniqueString;
	actions[uniqueString] = (){
		removeEmail(email);
	};
	sendEmail(email,format(`
This email address was entered to be removed from the Stellenbosch mathematics colloquium mailing list.
Please ignore this message if you do not want to be removed (or aren't on the list).
Please enter the following link in your browser to be remove:
http://%s/action/%s
`,hostName,uniqueString));
	res.redirect("/");
}

void doActionHandler(HTTPServerRequest req, HTTPServerResponse res) {
	auto uid = req.params.get("uid","");
	if(auto action = uid in actions) {
		(*action)();
	}
	res.redirect("/");
}
void hello(HTTPServerRequest req, HTTPServerResponse res) {
	res.writeBody(
`
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <title>title</title>
  </head>
  <body>
    <form method="post">
    <label for="emailAddress"> Email: </label>
    <input name="emailAddress" id="emailAddress" type="text">
    <input type="submit" value="Add to mailing list" formaction="/add">
    <input type="submit" value="Remove from mailing list" formaction="/remove">
    </form>
  </body>
</html>
`
	,"text/html");
}
