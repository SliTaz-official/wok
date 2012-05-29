/* ZeroBin 0.11 - http://sebsauvage.net/wiki/doku.php?id=php:zerobin */

// Compress a message (deflate compression). Returns base64 encoded data.
function compress(message) { return Base64.toBase64(RawDeflate.deflate(Base64.utob(message))); }

// Decompress a message compressed with compress().
function decompress(data) { return Base64.btou(RawDeflate.inflate(Base64.fromBase64(data))) }

/*
 Encrypt the message with a random key.
 Output: An array with two items:
     'data' (string) : json encoded data to store on server side (containing ciphertext,iv and salt)
     'key' (string: the key (encoded in base64) to be kept on client side.

 Example:
    c = randomCipher("Hello, world !");
    document.write("Data for server side: ");
    document.write(c.data);
    document.write('<br>Key at client side: ');
    document.write(c.key);
 Output:
    Data for server side: {"iv":"a6ZEUEtK2jNcGsdIsKKj9g","salt":"/7wDPD4JRik","ct":"qdD97HChan6B9OShjfBDmQKbw8/1ehdO1u/KbC/r85c"}
    Key at client side: VjxODsAaUwar6LJOcc0yaknnUr5XHeg/m7Sn5UF+TC4=
*/
function randomCipher(message)
{
    var randomkey = (window.location.hash.length > 2) ?
    	// force key
    	window.location.hash.substring(1) :
    	// Generate a random 256 bits key, encoded in base64:
    	sjcl.codec.base64.fromBits(sjcl.random.randomWords(8,0),0);
    var	data = sjcl.encrypt(sjcl.misc.pbkdf2(randomkey,0),compress(message));
    return {'data':data,'key':randomkey};
}

// Decrypts data encrypted with randomCipher()
function randomDecipher(key,data)
{
    return decompress(sjcl.decrypt(sjcl.misc.pbkdf2(key,0),data));
}

// Returns the current script location (without search or hash part of the URL).
// eg. http://server.com/zero/?aaaa#bbbb --> http://server.com/zero/
function scriptLocation()
{
    return window.location.href.substring(0,window.location.href.length
               -window.location.search.length -window.location.hash.length);
}

// Show decrypted text in the display area
function displayCleartext(text)
{                    
    if ($('#oldienotice').is(":visible"))  // For IE<10.
    {
        // IE<10 do not support white-space:pre-wrap; so we have to do this BIG UGLY STINKING THING.
        $('#cleartext').text(text.replace(/\n/ig,'{BIG_UGLY_STINKING_THING__OH_GOD_I_HATE_IE}'));
        $('#cleartext').html($('#cleartext').text().replace(/{BIG_UGLY_STINKING_THING__OH_GOD_I_HATE_IE}/ig,"\r\n<br>"));
    }
    else // for other (sane) browsers:
    {
        $('#cleartext').text(text);
    }
    urls2links($('#cleartext')); // Convert URLs to clickable links.
}

// Send data to server
function send_data()
{
    if ($('#message').val().length==0) return; // Do not send if no data.
    showStatus('Sending data...');
    var c=randomCipher($('#message').val());
    $.post(scriptLocation(), { data:c.data,expire:$('select#pasteExpiration').val()  },'json' )
    .error( function() { showError('Data could not be sent.'); } )
    .success(function(data)
             {
                var jdata = jQuery.parseJSON(data);
                if (data.status==0) 
                {
                    stateExistingPaste();
                    var url=scriptLocation()+"?"+data.id+'#'+c.key; 
                    showStatus('');
                    $('#pastelink').html('Your paste is <a href="'+url+'">'+url+'</a>');
                    $('#pastelink').append('&nbsp;&nbsp;<button id="shortenbutton" onclick="document.location=\''+shortenUrl(url)+'\'"><img src="lib/icon_shorten.png#" width="13" height="15" />Shorten URL</button>');
                    $('#pastelink').show();
                    displayCleartext($('#message').val());
                }
                else if (data.status==1) 
                { 
                    showError('Could not create paste: '+data.message); 
                }
                else
                { 
                    showError('Could not create paste.'); 
                }
             }
    );
}

// Put the screen in "New paste" mode.
function stateNewPaste()
{
    sjcl.random.startCollectors();
    $('#sendbutton').show();
    $('#clonebutton').hide();
    $('#expiration').show();
    $('#language').hide(); // $('#language').show();
    $('#password').hide(); //$('#password').show();
    $('#newbutton').show();
    $('#pastelink').hide();
    $('#message').text('');
    $('#message').show();
    $('#cleartext').hide();
    $('#hashes').hide();
    $('#message').focus();
}

// Put the screen in "Existing paste" mode.
function stateExistingPaste()
{
    sjcl.random.startCollectors();
    $('#sendbutton').hide();
    if (!$('#oldienotice').is(":visible")) $('#clonebutton').show(); // Not "clone" for IE<10.
    $('#expiration').hide();
    $('#language').hide();
    $('#password').hide();
    $('#newbutton').show();
    $('#pastelink').hide();
    $('#message').hide();
    $('#cleartext').show();
    $('#hashes').show();
}

// Clone the current paste.
function clonePaste()
{
    stateNewPaste();
    showStatus('');
    $('#message').text($('#cleartext').text());
}

// Create a new paste.
function newPaste()
{
    stateNewPaste();
    showStatus('');
    $('#message').text('');
}

// Display an error message
function showError(message)
{
    $('#status').addClass('errorMessage').text(message);
}

// Display status
function showStatus(message)
{
    $('#status').removeClass('errorMessage');
    if (!message) { $('#status').html('&nbsp'); return; }
    if (message=='') { $('#status').html('&nbsp'); return; }
    $('#status').text(message);
}

// Generate link to URL shortener.
function shortenUrl(url)
{
    return 'http://snipurl.com/site/snip?link='+encodeURIComponent(url);
}

// Convert URLs to clickable links.
// Input: element : a jQuery DOM element.
// Example URLs to handle:
//   magnet:?xt.1=urn:sha1:YNCKHTQCWBTRNJIV4WNAE52SJUQCZO5C&xt.2=urn:sha1:TXGCZQTH26NL6OUQAJJPFALHG2LTGBC7
//   http://localhost:8800/zero/?6f09182b8ea51997#WtLEUO5Epj9UHAV9JFs+6pUQZp13TuspAUjnF+iM+dM=
//   http://user:password@localhost:8800/zero/?6f09182b8ea51997#WtLEUO5Epj9UHAV9JFs+6pUQZp13TuspAUjnF+iM+dM=
// FIXME: add ppa & apt links.
function urls2links(element)
{
    var re = /((http|https|ftp):\/\/[\w?=&.\/-;#@~%+-]+(?![\w\s?&.\/;#~%"=-]*>))/ig;
    element.html(element.html().replace(re,'<a href="$1" rel="nofollow">$1</a>'));
    var re = /((magnet):[\w?=&.\/-;#@~%+-]+)/ig;
    element.html(element.html().replace(re,'<a href="$1">$1</a>'));
}

$(document).ready(function() {
    if ($('#cipherdata').text().length>1) // Display an existing paste
    {
       if (window.location.hash.length==0) // Missing decryption key in URL ?
       {
           showError('Cannot decrypt paste: Decryption key missing in URL (Did you use a redirector which strips part of the URL ?)');
           return;
       }
       var data = $('#cipherdata').text();
       try {
            // Get key and decrypt data
            var key = window.location.hash.substring(1);
            // Strip &utm_source=... parameters added after the anchor by some stupid web 2.0 services.
            // We simply strip everything after &
            i = key.indexOf('&'); if (i>-1) { key = key.substring(0,i); }
            if (key.charAt(key.length-1)!=='=') key+='='; // Add trailing = if missing.
            var cleartext = randomDecipher(key,data);
            stateExistingPaste();  // Show proper elements on screen.
            displayCleartext(cleartext);       
       } catch(err) {
           showError('Could not decrypt data (Wrong key ?)');
       }
    }
    else if ($('#errormessage').text().length>1) // Display error message from php code.
    {
        showError($('#errormessage').text());
    }
    else // Create a new paste.
    {
        newPaste();
    }
});
