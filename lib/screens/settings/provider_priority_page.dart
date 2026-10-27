import 'package:flutter/material.dart';
import 'package:tango/l10n/l10n.dart';
import 'package:tango/providers/extension_provider.dart';
import 'package:tango/screens/settings/provider_priority_list_page.dart';

class ProviderPriorityPage extends StatelessWidget {
  const ProviderPriorityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderPriorityListPage(
      loadAllProviders: (ref) =>
          ref.read(extensionProvider.notifier).getAllDownloadProviders(),
      currentPriority: (ref) => ref.read(extensionProvider).providerPriority,
      save: (ref, priority) =>
          ref.read(extensionProvider.notifier).setProviderPriority(priority),
      title: (c) => c.l10n.providerPriorityTitle,
      description: (c) => c.l10n.providerPriorityDescription,
      infoText: (c) => c.l10n.providerPriorityInfo,
      savedSnackbar: (c) => c.l10n.snackbarProviderPrioritySaved,
    );
  }
}
