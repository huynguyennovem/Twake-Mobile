import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:twake/blocs_new/channels_cubit/channels_state.dart';
import 'package:twake/models/channel/channel.dart';
import 'package:twake/models/globals/globals.dart';
import 'package:twake/repositories/channels_repository.dart';
import 'package:twake/services/service_bundle.dart';

export 'package:twake/models/channel/channel.dart';
export 'package:twake/blocs_new/channels_cubit/channels_state.dart';

abstract class BaseChannelsCubit extends Cubit<ChannelsState> {
  final ChannelsRepository _repository;

  BaseChannelsCubit({required ChannelsRepository repository})
      : _repository = repository,
        super(ChannelsInitial());

  void fetch({required String workspaceId}) async {
    emit(ChannelsLoadInProgress());

    final channelsStream = _repository.fetch(
      companyId: Globals.instance.companyId,
      workspaceId: workspaceId,
    );

    await for (final channels in channelsStream) {
      Channel? selected;
      if (this.state is ChannelsLoadedSuccess) {
        selected = (this.state as ChannelsLoadedSuccess).selected;
      }
      emit(ChannelsLoadedSuccess(
        channels: channels,
        selected: selected,
        hash: channels.fold(0, (acc, c) => acc + c.hash),
      ));
    }
  }

  Future<bool> create({
    required String name,
    String? icon,
    String? description,
    required ChannelVisibility visibility,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    var channel = Channel(
      id: now.toString(),
      name: name,
      icon: icon,
      description: description,
      companyId: Globals.instance.companyId!,
      workspaceId: Globals.instance.workspaceId!,
      members: const [],
      lastActivity: now,
      visibility: visibility,
      permissions: const [],
    );
    try {
      channel = await _repository.create(channel: channel);
    } catch (e) {
      Logger().e('Error occured during channel creation:\n$e');
      return false;
    }
    final channels = (state as ChannelsLoadedSuccess).channels;
    final hash = (state as ChannelsLoadedSuccess).hash;

    channels.insert(0, channel);
    emit(ChannelsLoadedSuccess(
      channels: channels,
      selected: channel,
      hash: hash + channel.hash,
    ));
    return true;
  }

  Future<bool> edit({
    required Channel channel,
    String? name,
    String? icon,
    String? description,
    ChannelVisibility? visibility,
  }) async {
    channel = channel.copyWith(
      name: name,
      icon: icon,
      description: description,
      visibility: visibility,
    );

    await _repository.edit(channel: channel);

    return true;
  }
}

class ChannelsCubit extends BaseChannelsCubit {
  ChannelsCubit({ChannelsRepository? repository})
      : super(repository: repository ?? ChannelsRepository());
}

class DirectsCubit extends BaseChannelsCubit {
  DirectsCubit({ChannelsRepository? repository})
      : super(
          repository: repository == null
              ? ChannelsRepository(endpoint: Endpoint.directs)
              : repository,
        );
}