# Preserve the stock document verbatim, changing only the output earpiece
# profile masks. Comments must not be interpreted as live XML elements.
{ document = document $0 "\n" }
END {
    rest = document
    output = ""
    while (length(rest)) {
        if (substr(rest, 1, 4) == "<!--") {
            end = index(rest, "-->")
            if (!end) exit 1
            size = end + 2
        } else if (substr(rest, 1, 1) != "<") {
            size = index(rest, "<") - 1
            if (size < 0) size = length(rest)
        } else {
            size = index(rest, ">")
            if (!size) exit 1
        }
        token = substr(rest, 1, size)
        rest = substr(rest, size + 1)
        if (token ~ /^<devicePort[[:space:]]/) {
            if (earpiece) exit 1
            earpiece = token ~ /type[[:space:]]*=[[:space:]]*["\047]AUDIO_DEVICE_OUT_EARPIECE["\047]/ && token ~ /role[[:space:]]*=[[:space:]]*["\047]sink["\047]/
            if (earpiece) ports++
        } else if (token ~ /^<\/devicePort[[:space:]]*>/) {
            earpiece = 0
        } else if (earpiece && token ~ /^<profile[[:space:]]/) {
            if (token !~ /channelMasks[[:space:]]*=[[:space:]]*["\047]AUDIO_CHANNEL_OUT_(MONO|STEREO)["\047]/) exit 1
            if (match(token, /channelMasks[[:space:]]*=[[:space:]]*["\047]AUDIO_CHANNEL_OUT_MONO["\047]/)) {
                start = RSTART
                count = RLENGTH
                mask = substr(token, start, count)
                sub(/AUDIO_CHANNEL_OUT_MONO/, "AUDIO_CHANNEL_OUT_STEREO", mask)
                token = substr(token, 1, start - 1) mask substr(token, start + count)
            }
            profiles++
        }
        output = output token
    }
    if (earpiece || ports != 1 || profiles < 1) exit 1
    printf "%s", output
}
