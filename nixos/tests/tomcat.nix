import ./make-test-python.nix (
  { lib, pkgs, ... }:
  {
    name = "tomcat";
    meta.maintainers = [ lib.maintainers.anthonyroussel ];

    nodes.machine =
      { pkgs, ... }:
      {
        services.tomcat = {
          enable = true;
          port = 8001;
          axis2.enable = true;
        };
      };

    testScript = ''
      machine.wait_for_unit("tomcat.service")
      machine.wait_for_open_port(8001)
      machine.wait_for_file("/var/tomcat/webapps/examples");

      machine.succeed(
          "curl -sS --fail http://localhost:8001/examples/servlets/servlet/HelloWorldExample | grep 'Hello World!'"
      )
      machine.succeed(
          "curl -sS --fail http://localhost:8001/examples/jsp/jsp2/simpletag/hello.jsp | grep 'Hello, world!'"
      )
      machine.succeed(
          "curl -sS --fail http://localhost:8001/axis2/axis2-web/HappyAxis.jsp | grep 'Found Axis2'"
      )
    '';
  }
)
