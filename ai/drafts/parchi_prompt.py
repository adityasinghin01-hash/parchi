"""The one prompt shared by training, testing and the iMac server. Change it in one place only."""
PROMPT = ("You are reading an Indian doctor's prescription (parchi). List every medicine and every lab test "
          "exactly as written. Reply with JSON only: {\"medicines\":[{\"name\":\"brand and strength\",\"form\":\"Tab/Cap/Syp/...\","
          "\"dose\":\"...\",\"duration\":\"...\"}],\"tests\":[\"...\"]}. If there are none, use empty lists.")
