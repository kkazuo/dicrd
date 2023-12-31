// ignore_for_file: constant_identifier_names

/*
  Copyright © 2023 Koga Kazuo <kkazuo@kkazuo.com>

  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

enum NumericReply {
  RPL_AWAY(301, ''),
  RPS_ISON(303, ''),
  RPL_UNAWAY(305, 'You are no longer marked as being away'),
  RPL_NOWAWAY(306, 'You have been marked as being away'),
  RPL_CHANNELMODEIS(324, ''),
  RPL_NOTOPIC(331, 'No topic is set'),
  RPL_TOPIC(332, '<topic>'),
  RPL_NAMREPLY(353, ''),
  RPL_ENDOFNAMES(366, 'End of /NAMES list'),
  RPL_MOTD(372, ''),
  RPL_MOTDSTART(375, ''),
  RPL_ENDOFMOTD(376, 'End of MOTD command'),
  ERR_NOSUCHNICK(401, 'No such nick/channel'),
  ERR_NOSUCHCHANNEL(403, 'No such channel'),
  ERR_TOOMANYTARGETS(407, '<error code> recipients. <abort message>'),
  ERR_NOORIGIN(409, 'No origin specified'),
  ERR_INVALIDCAPCMD(410, 'Invalid CAP command'),
  ERR_NORECIPIENT(411, 'No recipient given'),
  ERR_NOTEXTTOSEND(412, 'No text to send'),
  ERR_NOTOPLEVEL(413, 'No toplevel domain specified'),
  ERR_WILDTOPLEVEL(414, 'Wildcard in toplevel domain'),
  ERR_BADMASK(415, 'Bad Server/host mask'),
  ERR_UNKNOWNCOMMAND(421, 'Unknown command'),
  ERR_NOMOTD(422, 'MOTD File is missing'),
  ERR_NONICKNAMEGIVEN(431, 'No nickname given'),
  ERR_ERRONEUSNICKNAME(432, 'Erroneous nickname'),
  ERR_NICKNAMEINUSE(433, 'Nickname is already in use'),
  ERR_NICKCOLLISION(436, 'Nickname collision KILL from <user>@<host>'),
  ERR_UNAVAILRESOURCE(437, 'Nick/channel is temporarily unavailable'),
  ERR_NOTONCHANNEL(442, "You're not on that channel"),
  ERR_NEEDMOREPARAMS(461, 'Not enough parameters'),
  ERR_ALREADYREGISTRED(462, 'Unauthorized command (already registered)'),
  ERR_PASSWDMISMATCH(464, 'Password incorrect'),
  ERR_KEYSET(467, 'Channel key already set'),
  ERR_UNKNOWNMODE(472, 'is unknown mode char to me for <channel>'),
  ERR_BADCHANNELKEY(475, 'Cannot join channel (+k)'),
  ERR_NOCHANMODES(477, "Channel doesn't support modes"),
  RPL_LOGGEDIN(900, 'You are now logged in.'),
  RPL_LOGGEDOUT(901, 'You are now logged out.'),
  ERR_NICKLOCKED(902, 'You must use a nick assigned to you.'),
  RPL_SASLSUCCESS(903, 'SASL authentication successful'),
  ERR_SASLFAILED(904, 'SASL authentication failed'),
  ERR_SASLTOOLONG(905, 'SASL message too long'),
  ERR_SASLABORTED(906, 'SASL authentication aborted'),
  ERR_SASLALREADY(907, 'You have already completed SASL authentication'),
  RPL_SASLMECHS(908, 'are available SASL mechanisms'),
  ;

  final int code;
  final String desc;

  const NumericReply(this.code, this.desc);
}
