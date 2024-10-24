{config, ...}:

{

  sops.secrets.pia-credentials = {
    # owner = "cyberfighter";
  };

    services.openvpn.servers = {
    pia = {
      autoStart = false;
      
      # Most of these options came from the OVPN file from the generator
      config = ''
        client
        dev tun
        proto udp
        remote us-newjersey.privacy.network 1198
        resolv-retry infinite
        nobind
        persist-key
        persist-tun
        cipher aes-128-cbc
        auth sha1
        tls-client
        remote-cert-tls server

        auth-user-pass
        compress
        verb 1
        reneg-sec 0

        # These settings was included directly in the file from
        # the generator, but I moved them to external files.
        # crl-verify ${./crl.pem}
        ca ${./ca.pem}

        disable-occ

        auth-user-pass /run/secrets/pia-credentials
      '';
    };
  };

}
