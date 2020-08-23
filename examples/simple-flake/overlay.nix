final: prev:
{
  # this key should be the same as the simpleFlake name attribute.
  simple-flake = {
    # assuming that hello is a project-specific package;
    hello = prev.hello;

    # demonstrating recursive packages
    terraform-providers = prev.terraform-providers;
  };
}
