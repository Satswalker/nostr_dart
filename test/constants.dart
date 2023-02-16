class TestConstants {
  static const String id =
      "3e021e41017828b7ea873bf79f6c4f5f93fbef0cd6c4fa02ddaa27e15b11fbcf";
  static const String idNotHex =
      "04739d4238d206aq714bd5740b800f1b5b8546dcf3389bd76b1f0f29ec69d6f5";
  static const String idWrongLength =
      "04739d4238d206a3714bd5740b800f1b5b8546dcf3389bd76b1f0f29ec69d6f";
  static const String publicKey =
      "19f6ddd75274b0d0ca1a14df58a20a422639f70a82a967403f521f20f558b4bc";
  static const String privateKey =
      "7f5c15b6c8c82477b293f0d7fc296e0a067fd48de66e9847b3e98e29c3ecb3ac";
  static const String keyNotHex =
      "19f6ddd75274b0d0ca1a14df58a20a422i39f70a82a967403f521f20f558b4bc";
  static const String keyWrongLength =
      "19f6ddd75274b0d0ca1a14df58a20a422639f70a82a967403f521f20f558b4be11";
  static const int timestamp = 1640948400;
  static const int kindTextNote = 1;
  static const emptyTags = [];
  static const String content =
      "The Times 03/Jan/2009 Chancellor on brink of second bailout for banks";
  static const String sig =
      "b1edeb12e278f380432ddd3c6a8f4ea8052f4f1cd47f2e08f928bb2ea124fe78e864c9bb7822bff3e3da6301ea2c07cf4904d4a1adb0b4d4247c52fdbe495918";
  static const relayEvent1 = [
    "EVENT",
    "ecda476b0968c04a886c8862467e630b8ccdd2c96d44d62c0c8060ce8001511d",
    {
      "id": "88584637dd3434e0694165581455a6f9ec9010831a0cf1c2b65ae52c677dfea6",
      "pubkey":
          "2ef93f01cd2493e04235a6b87b10d3c4a74e2a7eb7c3caf168268f6af73314b5",
      "created_at": 1658935344,
      "kind": 1,
      "tags": [
        [
          "e",
          "837547a2cd2fe19a5276a62bebc3adf34b8a9386ceab12a122026d737931df65",
          "",
          "reply"
        ],
        [
          "p",
          "f00c952da33c06e02c930f76aba1085021b98075657daaff8ad119edcfde691e"
        ],
        ["client", "more-speech - 202207230955"]
      ],
      "content": "The world says hello.",
      "sig":
          "9277844a78828798dfdf9a4e9b969ee022b962dd6d6a2a1f68f01696388e81dd9430cb2ebbd98aaa65569081f6b1133b9dc4fa68b1e3d270ca3a86c7988de916"
    }
  ];
  static const relayEvent2 = [
    "EVENT",
    "9c0c7e2ac840714104f7cd2dc2d7426d516bd8b91994c020a86b3ce3c6f57eff",
    {
      "id": "ef340ed732776c226307bc3ed5d3d75ba0c9c784214557dbab0819a027d51ce9",
      "pubkey":
          "2ef93f01cd2493e04235a6b87b10d3c4a74e2a7eb7c3caf168268f6af73314b5",
      "created_at": 1665754887,
      "kind": 1,
      "tags": [
        [
          "e",
          "8714cbbe438d9572224ad5e839e60c36c67a6bff8f444938e594cb7ccef6e78e",
          "",
          "root"
        ],
        [
          "e",
          "b074b5d3ee1a876f7201355d4c31faef85986408f1ba9144abb56005176699a1",
          "",
          "reply"
        ],
        [
          "p",
          "392daba0ea24dbe3ff28756b8e2e24af91764f5bf68878b4b87f5192a7db61e7"
        ],
        [
          "p",
          "32e1827635450ebb3c5a7d12c1f8e7b2b514439ac10a67eef3d9fd9c5c68e245"
        ],
        [
          "p",
          "00000000827ffaa94bfea288c3dfce4422c794fbb96625b6b31e9049f729d700"
        ],
        [
          "p",
          "24e37c1e5b0c8ba8dde2754bcffc63b5b299f8064f8fb928bcf315b9c4965f3b"
        ],
        ["client", "more-speech - 202209201153"]
      ],
      "content": "Hi!",
      "sig":
          "22551f790470305f60e336c9d8ad2b9b2215537c090de6be32e6ba8fa506449965dffac751eff6c7c8000974aee3e145e64cc7ac3cf630dcfeb0584a516f03bc"
    }
  ];

  static const clientEvent1 = [
    "EVENT",
    {
      "id": "88584637dd3434e0694165581455a6f9ec9010831a0cf1c2b65ae52c677dfea6",
      "pubkey":
          "2ef93f01cd2493e04235a6b87b10d3c4a74e2a7eb7c3caf168268f6af73314b5",
      "created_at": 1658935344,
      "kind": 1,
      "tags": [
        [
          "e",
          "837547a2cd2fe19a5276a62bebc3adf34b8a9386ceab12a122026d737931df65",
          "",
          "reply"
        ],
        [
          "p",
          "f00c952da33c06e02c930f76aba1085021b98075657daaff8ad119edcfde691e"
        ],
        ["client", "more-speech - 202207230955"]
      ],
      "content": "The world says hello.",
      "sig":
          "9277844a78828798dfdf9a4e9b969ee022b962dd6d6a2a1f68f01696388e81dd9430cb2ebbd98aaa65569081f6b1133b9dc4fa68b1e3d270ca3a86c7988de916"
    }
  ];
  static const clientEvent2 = [
    "EVENT",
    {
      "id": "ef340ed732776c226307bc3ed5d3d75ba0c9c784214557dbab0819a027d51ce9",
      "pubkey":
          "2ef93f01cd2493e04235a6b87b10d3c4a74e2a7eb7c3caf168268f6af73314b5",
      "created_at": 1665754887,
      "kind": 1,
      "tags": [
        [
          "e",
          "8714cbbe438d9572224ad5e839e60c36c67a6bff8f444938e594cb7ccef6e78e",
          "",
          "root"
        ],
        [
          "e",
          "b074b5d3ee1a876f7201355d4c31faef85986408f1ba9144abb56005176699a1",
          "",
          "reply"
        ],
        [
          "p",
          "392daba0ea24dbe3ff28756b8e2e24af91764f5bf68878b4b87f5192a7db61e7"
        ],
        [
          "p",
          "32e1827635450ebb3c5a7d12c1f8e7b2b514439ac10a67eef3d9fd9c5c68e245"
        ],
        [
          "p",
          "00000000827ffaa94bfea288c3dfce4422c794fbb96625b6b31e9049f729d700"
        ],
        [
          "p",
          "24e37c1e5b0c8ba8dde2754bcffc63b5b299f8064f8fb928bcf315b9c4965f3b"
        ],
        ["client", "more-speech - 202209201153"]
      ],
      "content": "Hi!",
      "sig":
          "22551f790470305f60e336c9d8ad2b9b2215537c090de6be32e6ba8fa506449965dffac751eff6c7c8000974aee3e145e64cc7ac3cf630dcfeb0584a516f03bc"
    }
  ];
}
