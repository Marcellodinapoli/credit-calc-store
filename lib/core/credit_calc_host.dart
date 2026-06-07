import 'package:credit_calc_core/credit_calc_core.dart';

import 'package:flutter/material.dart';



import '../ui/layout/page_shell.dart';



/// Integra le pagine CreditCalc con la shell responsive dell'app store.

void registerCreditCalcHost() {

  creditCalcPageWrapper = (params) {

    if (params.secondary) {

      return CreditCalcSecondaryLayout(

        pageTitle: params.pageTitle,

        body: params.body,

        bottomBar: params.bottomBar,

      );

    }



    return CreditCalcPrimaryLayout(

      pageTitle: params.pageTitle,

      current: params.current,

      body: params.body,

    );

  };

}



class CreditCalcPrimaryLayout extends StatelessWidget {

  final String pageTitle;

  final Widget body;

  final CreditCalcNavItem? current;



  const CreditCalcPrimaryLayout({

    super.key,

    required this.pageTitle,

    required this.body,

    this.current,

  });



  @override

  Widget build(BuildContext context) {

    return PageShellBody(pageTitle: pageTitle, child: body);

  }

}



class CreditCalcSecondaryLayout extends StatelessWidget {

  final String pageTitle;

  final Widget body;

  final Widget? bottomBar;

  final bool padded;



  const CreditCalcSecondaryLayout({

    super.key,

    required this.pageTitle,

    required this.body,

    this.bottomBar,

    this.padded = true,

  });



  @override

  Widget build(BuildContext context) {

    return SecondaryPageScaffold(

      pageTitle: pageTitle,

      padded: padded,

      bottomBar: bottomBar,

      body: body,

    );

  }

}


