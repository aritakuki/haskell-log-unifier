# ApacheにERROR Aが出たらネットワーク障害の可能性があります
rule "network_failure" {
  pattern: "ERROR A"
  transform: {
    message: "ネットワーク障害の可能性があります"
  }
}
