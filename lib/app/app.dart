import 'package:ocs_agent/core/api.dart' as api;

import 'package:ocs_agent/core/inventory/linux/baseLinux.dart' as baseLinux;

///in this main section we send the [body] to the asset/bases
void main(List<String> args) async {
  var sendBody = new api.Api();

  sendBody.generateToken();

  sendBody.apiCheck();

  sendBody.getHeader();

  sendBody.sendInventory(await baseLinux.getBody());
}
