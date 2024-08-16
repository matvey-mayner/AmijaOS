local result = require("sha256").sha256hex("TEST SHA256 INPUT DATA") == "08719f850b98037569a57205d9dc7b6a62d4fbf1a1ebcafefefa947e91bf05e9"
require("package").unload("sha256")
return result