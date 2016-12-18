# See DEPLOY-GCE.md for details on setting up this file.
import ./physical.gce.nix {
  credentials    = import ./gce.keys.nix;  # Create this file from ./gce.keys.nix.sample
  machineRegion  = "us-central1-f";        # See GCE's options for VM instance region
  staticIpRegion = "us-central1";          # See GCE's options for static IP region (must be in the same general region as the attached instance)
}
