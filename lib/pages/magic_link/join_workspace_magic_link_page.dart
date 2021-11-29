import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:sprintf/sprintf.dart';
import 'package:twake/blocs/authentication_cubit/authentication_cubit.dart';
import 'package:twake/config/image_path.dart';
import 'package:twake/config/styles_config.dart';
import 'package:twake/models/deeplink/join/workspace_join_response.dart';
import 'package:twake/models/globals/globals.dart';
import 'package:twake/services/endpoints.dart';
import 'package:twake/widgets/common/button_text_builder.dart';
import 'package:url_launcher/url_launcher.dart';

class JoinWorkSpaceMagicLinkPage extends StatefulWidget {

  final WorkspaceJoinResponse? workspaceJoinResponse;
  final String requestedToken;

  const JoinWorkSpaceMagicLinkPage({Key? key, this.workspaceJoinResponse, required this.requestedToken}) : super(key: key);

  @override
  _JoinWorkSpaceMagicLinkPageState createState() => _JoinWorkSpaceMagicLinkPageState();
}

class _JoinWorkSpaceMagicLinkPageState extends State<JoinWorkSpaceMagicLinkPage> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          width: double.maxFinite,
          height: double.maxFinite,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                children: [
                  SizedBox(height: 8),
                  Image.asset(imageTwakeHomeLogo),
                  SizedBox(height: 20),
                  Text(AppLocalizations.of(context)?.joinWorkspaceIntro ?? '',
                      style: StylesConfig.commonTextStyle.copyWith(fontSize: 15)),
                ],
              ),
              (widget.workspaceJoinResponse == null)
                ? _buildUnAvailableLayout(widget.workspaceJoinResponse)
                : _buildAvailableLayout(widget.workspaceJoinResponse)
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvailableLayout(WorkspaceJoinResponse? workspaceJoinResponse) =>
    Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(imageSmileFace, width: 88, height: 88),
        SizedBox(height: 20),
        RichText(
            text: TextSpan(
              children: <TextSpan>[
                TextSpan(text: AppLocalizations.of(context)?.joinWorkspaceTitle ?? '',
                    style: StylesConfig.commonTextStyle.copyWith(fontWeight: FontWeight.w600, fontSize: 20)),
                TextSpan(text: workspaceJoinResponse?.workspace.name ?? '',
                    style: StylesConfig.commonTextStyle.copyWith(fontWeight: FontWeight.w600, fontSize: 20, color: Color(0xff004dff))),
              ],
            )),
        SizedBox(height: 36),
        Text(AppLocalizations.of(context)?.joinWorkspaceSubTitle(workspaceJoinResponse?.workspace.name ?? '') ?? '', style: TextStyle(fontSize: 15), textAlign: TextAlign.center),
        SizedBox(height: 12),
        ButtonTextBuilder(Key('button_join_workspace'),
            onButtonClick: () => _handleClickOnJoinButton())
            .setHeight(50)
            .setText(AppLocalizations.of(context)?.joinWorkspaceButton ?? '')
            .build()
      ],
    );

  Widget _buildUnAvailableLayout(WorkspaceJoinResponse? workspaceJoinResponse) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Image.asset(imageShrugging, width: 98, height: 88),
      SizedBox(height: 20),
      Text(AppLocalizations.of(context)?.joinWorkspaceUnAvailableTitle ?? '',
          style: StylesConfig.commonTextStyle.copyWith(fontWeight: FontWeight.w600, fontSize: 20)),
      SizedBox(height: 36),
      Text(AppLocalizations.of(context)?.joinWorkspaceUnAvailableSubTitle ?? '', style: TextStyle(fontSize: 15), textAlign: TextAlign.center),
      SizedBox(height: 12),
      ButtonTextBuilder(Key('button_create_company'),
          onButtonClick: () => _handleClickOnCreateCompanyButton())
          .setHeight(50)
          .setText(AppLocalizations.of(context)?.joinWorkspaceCreateCompanyButton ?? '')
          .build(),
      SizedBox(height: 14),
      Text(AppLocalizations.of(context)?.joinWorkspaceUnAvailableNote ?? '', style: TextStyle(fontSize: 13), textAlign: TextAlign.center),
    ],
  );

  void _handleClickOnJoinButton() async {
    await Get.find<AuthenticationCubit>().joinWorkspace(widget.requestedToken, needCheckAuthentication: true);
    if(!mounted)
      return;
    Navigator.of(context).pop();
  }

  void _handleClickOnCreateCompanyButton() async {
    try {
      final consolePage = sprintf(Endpoint.consolePage, [Globals.instance.host.split('.').skip(1).join('.')]);
      await canLaunch(consolePage)
          ? await launch(consolePage)
        : throw 'Could not launch $consolePage';
    } catch (e) {
    Logger().e('ERROR during opening console page:\n$e');
    }
  }

}