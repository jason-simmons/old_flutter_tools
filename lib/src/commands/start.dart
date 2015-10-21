// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

import '../application_package.dart';
import '../device.dart';
import 'build.dart';
import 'flutter_command.dart';
import 'install.dart';
import 'stop.dart';

final Logger _logging = new Logger('sky_tools.start');

class StartCommand extends FlutterCommand {
  final String name = 'start';
  final String description = 'Start your Flutter app on attached devices.';

  StartCommand() {
    argParser.addFlag('poke',
        negatable: false,
        help: 'Restart the connection to the server (Android only).');
    argParser.addFlag('checked',
        negatable: true,
        defaultsTo: true,
        help: 'Toggle Dart\'s checked mode.');
    argParser.addOption('target',
        defaultsTo: '.',
        abbr: 't',
        help: 'Target app path or filename to start.');
    argParser.addFlag('boot',
        help: 'Boot the iOS Simulator if it isn\'t already running.');
  }

  static const String _localBundlePath = 'app.flx';

  @override
  Future<int> run() async {
    await downloadApplicationPackagesAndConnectToDevices();

    bool poke = argResults['poke'];
    if (!poke) {
      StopCommand stopper = new StopCommand();
      stopper.inheritFromParent(this);
      stopper.stop();

      // Only install if the user did not specify a poke
      InstallCommand installer = new InstallCommand();
      installer.inheritFromParent(this);
      installer.install(boot: argResults['boot']);
    }

    bool startedSomething = false;

    for (Device device in devices.all) {
      ApplicationPackage package = applicationPackages.getPackageForPlatform(device.platform);
      if (package == null || !device.isConnected())
        continue;
      if (device is AndroidDevice) {
        BuildCommand builder = new BuildCommand();
        builder.inheritFromParent(this);
        builder.build(outputPath: _localBundlePath);
        if (device.startBundle(package, _localBundlePath, poke, argResults['checked']))
          startedSomething = true;
      } else {
        if (await device.startApp(package))
          startedSomething = true;
      }
    }

    if (!startedSomething) {
      if (!devices.all.any((device) => device.isConnected())) {
        _logging.severe('Unable to run application - no connected devices.');
      } else {
        _logging.severe('Unable to run application.');
      }
    }

    return startedSomething ? 0 : 2;
  }
}
