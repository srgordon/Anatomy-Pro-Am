var Exceptional = require('../lib/exceptional').Exceptional;

Exceptional.API_KEY = 'your-api-key-here';

process.addListener('uncaughtException', function(err) {
    Exceptional.handle(err);
});

try {
  throw new Error("Test Error 1");
} catch(error) {
  console.log("Error occurred ", error.message);
  Exceptional.handle(error);
}


throw new Error("Test Error 2");
