{
  description = "NixOS in MicroVMs";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-21.11";
  inputs.microvm.url = "github:astro/microvm.nix";
  inputs.microvm.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { self, nixpkgs, microvm }:
    let
      system = "x86_64-linux";
    in {
      defaultPackage.${system} = self.packages.${system}.cardano-here;

      packages.${system}.cardano-here =
        let
          inherit (self.nixosConfigurations.cardano-here) config;
          # quickly build with another hypervisor if this MicroVM is built as a package
          hypervisor = "qemu";
        in config.microvm.runner.${hypervisor};

      nixosConfigurations.cardano-here = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          microvm.nixosModules.microvm
          {
            networking.hostName = "cardano-here";
            users.users.root.password = "";
            microvm = {
              volumes = [ {
                mountPoint = "/var";
                image = "var.img";
                size = 256;
              } ];
              shares = [ {
                # use "virtiofs" for MicroVMs that are started by systemd
                proto = "9p";
                tag = "ro-store";
                # a host's /nix/store will be picked up so that the
                # size of the /dev/vda can be reduced.
                source = "/nix/store";
                mountPoint = "/nix/.ro-store";
              } ];
              socket = "control.socket";
              # relevant for delarative MicroVM management
              hypervisor = "qemu";
            };
          }
        ];
      };
    };
}
