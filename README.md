handbrake-encode
================

Wrapper script for handbrake

rip videos from DVDs using Handbrake

for information about Handbrake see: http://www.handbrake.fr/


written by Andreas 'ads' Scherbaum <ads@wars-nicht.de>

history:
 2013-01-12                initial version


license: New BSD License


Copyright (c) 2013, Andreas Scherbaum
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of Andreas Scherbaum nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL Andreas Scherbaum BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.




Available options:
 -h --help       display this help
    --debug      display debugging information (not available)
 -d --device     specify DVD device
    --min-time   specify minimum time for a track
    --max-time   specify maximum time for a track
    --name       specify output name, without format
 -c --continue   specify if the DVD is part of a collection and the
                 script should attach and increase a double-digit number
                 to each title, existing files with the same pattern
                 are considered
    --format     format of the output file (m4v, mkv)
    --audio      comma-separated list of 3-char language codes where the
                 audio track is to include in the output file
    --subtitle   comma-separated list of 3-char language codes where the
                 subtitle is to include in the output file
 -t --time       display the time when encoding started

If ~/.handbrake-encode.conf exists it will be parsed before applying
commandline options

