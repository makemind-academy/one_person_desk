import 'dart:async';
import 'dart:convert';

import 'package:mcp_server/mcp_server.dart';

import 'serve_bundle.dart';

/// desk_server — one person wearing every hat, on one screen.
///
/// The thing that actually hurts about running a business alone is not the
/// amount of work. It is the switching: an order, then a tax date, then a
/// supplier email, then back to the order — and each switch costs the thread
/// you were holding.
///
/// So the useful question is not "can one screen show everything" (it can, and
/// that is just a list). It is **what has to be true for the screen to be
/// worth trusting when you are the only one who can catch its mistakes.**
///
/// Two answers here. Every item says which hat it belongs to and where it came
/// from, so nothing appears without a source. And the ordering is stated as a
/// rule, not baked into a sort call, so the owner can see why the top item is
/// on top.
void main(List<String> args) async {
  const config = McpServerConfig(
    name: 'One Desk',
    version: '1.0.0',
    capabilities: ServerCapabilities(
      tools: ToolsCapability(listChanged: true),
      resources: ResourcesCapability(listChanged: true),
    ),
  );
  final server = McpServer.createServer(config);
  DeskServer(server).register();
  // The screen next door: AppPlayer reads it from here and sends the pages'
  // tool calls back to the tools above.
  registerBundleUi(server, '../desk.mbd');
  final transport = McpServer.createStdioTransport().get();
  server.connect(transport);
  await Completer<void>().future;
}

/// One thing on the desk, and the hat it belongs to.
class Item {
  const Item(this.hat, this.what, this.dueInDays, this.money, this.source);

  /// Which role this belongs to — sales, making, books, supply.
  final String hat;
  final String what;

  /// Negative means it is already late.
  final int dueInDays;

  /// Won at stake, as an integer. Zero for things that cost nothing to be
  /// late on.
  final int money;

  /// Where this came from. An item with no source is a note somebody typed and
  /// forgot; an item with one can be checked.
  final String source;
}

class DeskServer {
  DeskServer(this.server);

  final Server server;

  final _items = const [
    Item('books', 'VAT quarterly return', 5, 0, 'filing calendar rule'),
    Item('sales', 'Quote for Westbrook — 40 units', 1, 3200, 'inbox 04-18'),
    Item('supply', 'Reorder packaging film', -2, 480, 'stock below reorder point'),
    Item('making', 'Batch 118 labels', 3, 0, 'production plan'),
    Item('sales', 'Follow up Harborview, quoted 2 weeks ago', -9, 1750, 'quote log'),
    Item('books', 'Reconcile March card statement', 8, 0, 'bank feed'),
  ];

  /// Why the list is in this order, in words the owner can disagree with.
  ///
  /// A sort function hidden in code is a decision nobody can argue with. Naming
  /// the rule on the screen means the owner can look at the top item and say
  /// "no, the packaging can wait" — and know which rule to change.
  static const orderingRule =
      'late first, then money at stake, then soonest due';

  int _rank(Item a, Item b) {
    final aLate = a.dueInDays < 0;
    final bLate = b.dueInDays < 0;
    if (aLate != bLate) return aLate ? -1 : 1;
    if (a.money != b.money) return b.money.compareTo(a.money);
    return a.dueInDays.compareTo(b.dueInDays);
  }

  void register() {
    server.addTool(
      name: 'desk.all',
      description:
          'Everything on the desk, ordered by the stated rule, each item with '
          'its hat and its source',
      inputSchema: const {'type': 'object', 'properties': {}},
      handler: (args) async => _state(),
    );

    server.addTool(
      name: 'desk.hat',
      description: 'The same desk, narrowed to one hat',
      inputSchema: const {
        'type': 'object',
        'properties': {
          'hat': {'type': 'string'},
        },
        'required': ['hat'],
      },
      handler: (args) async => _state(hat: args['hat'] as String?),
    );
  }

  CallToolResult _state({String? hat}) {
    final picked = _items.where((i) => hat == null || i.hat == hat).toList()
      ..sort(_rank);

    final rows = picked
        .map((i) => {
              'hat': i.hat,
              'what': i.what,
              // One line, one shape: `late 9 d` / `due 1 d`. A cell that wraps
              // reads like prose and the column stops being a column.
              'due': i.dueInDays < 0
                  ? 'late ${-i.dueInDays} d'
                  : 'due ${i.dueInDays} d',
              'late': i.dueInDays < 0,
              // Shown in thousands of dollars to one decimal. The raw figure is
              // kept as an int so nothing is lost to formatting.
              'money': i.money == 0
                  ? ''
                  : '\$${(i.money / 1000).toStringAsFixed(1)}k',
              'source': i.source,
            })
        .toList();

    final late = picked.where((i) => i.dueInDays < 0).length;
    final hats = picked.map((i) => i.hat).toSet().toList()..sort();
    final atStake = picked.fold<int>(0, (s, i) => s + i.money);

    return CallToolResult(content: [
      TextContent(
        text: jsonEncode({
          'rows': rows,
          'rowCount': rows.length,
          'late': late,
          'hats': hats.join(' · '),
          'hatCount': hats.length,
          'atStake': '\$${(atStake / 1000).toStringAsFixed(1)}k',
          // The rule travels to the screen so the order can be argued with.
          'rule': orderingRule,
          'headline': late > 0
              ? '$late late across ${hats.length} hats'
              : 'nothing late across ${hats.length} hats',
        }),
      )
    ]);
  }
}
