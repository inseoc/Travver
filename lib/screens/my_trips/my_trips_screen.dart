import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../app/theme.dart';
import '../../app/routes.dart';
import '../../models/trip.dart';
import '../../providers/trip_provider.dart';
import '../../widgets/common/trip_card.dart';
import '../../services/storage_service.dart';

/// 내 여행 목록 화면
/// - 저장된 여행 계획 관리
class MyTripsScreen extends StatefulWidget {
  const MyTripsScreen({super.key});

  @override
  State<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends State<MyTripsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = ['전체', '예정', '진행중', '완료'];
  final StorageService _storageService = StorageService();
  Map<String, int> _photoCounts = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _loadPhotoCounts();
  }

  Future<void> _loadPhotoCounts() async {
    final counts = await _storageService.getAllPhotoCountsByTrip();
    if (mounted) {
      setState(() => _photoCounts = counts);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Trip> _getFilteredTrips(TripProvider provider, int tabIndex) {
    switch (tabIndex) {
      case 1:
        return provider.upcomingTrips;
      case 2:
        return provider.ongoingTrips;
      case 3:
        return provider.completedTrips;
      default:
        return provider.trips;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text('내 여행', style: AppTypography.subhead1),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.accent,
          tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
        ),
      ),
      body: Consumer<TripProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return TabBarView(
            controller: _tabController,
            children: List.generate(_tabs.length, (index) {
              final trips = _getFilteredTrips(provider, index);
              return _buildTripList(trips);
            }),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.planInput),
        icon: const Icon(Icons.add),
        label: const Text('새 여행'),
      ),
    );
  }

  Widget _buildTripList(List<Trip> trips) {
    if (trips.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppDimens.spacing16),
      itemCount: trips.length,
      itemBuilder: (context, index) {
        final trip = trips[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppDimens.spacing12),
          child: _buildTripListItem(trip),
        );
      },
    );
  }

  Widget _buildTripListItem(Trip trip) {
    return Dismissible(
      key: Key(trip.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppDimens.spacing20),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('여행 삭제'),
            content: Text('${trip.destination} 여행을 삭제하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text('삭제'),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        context.read<TripProvider>().deleteTrip(trip.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${trip.destination} 여행이 삭제되었습니다'),
            action: SnackBarAction(
              label: '실행취소',
              onPressed: () {
                // TODO: 삭제 취소 기능
              },
            ),
          ),
        );
      },
      child: GestureDetector(
        onTap: () => context.push(
          AppRoutes.tripDetail.replaceFirst(':tripId', trip.id),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimens.cardRadius),
            boxShadow: AppShadows.card,
          ),
          child: Row(
            children: [
              // 이미지
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(AppDimens.cardRadius),
                ),
                child: Container(
                  width: 100,
                  height: 100,
                  color: _getStatusColor(trip.status).withOpacity(0.15),
                  child: trip.imageUrl != null
                      ? Image.network(trip.imageUrl!, fit: BoxFit.cover)
                      : Icon(
                          Icons.flight_outlined,
                          size: 40,
                          color: _getStatusColor(trip.status).withOpacity(0.5),
                        ),
                ),
              ),

              // 정보
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimens.spacing12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              trip.destination,
                              style: AppTypography.subhead2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _buildStatusBadge(trip.status),
                        ],
                      ),
                      const SizedBox(height: AppDimens.spacing4),
                      Text(
                        trip.period.displayString,
                        style: AppTypography.body2.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppDimens.spacing4),
                      Row(
                        children: [
                          Text(
                            '${trip.travelers}명 · ${trip.budget.displayString}',
                            style: AppTypography.caption,
                          ),
                          if ((_photoCounts[trip.id] ?? 0) > 0) ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                context.push(
                                    AppRoutes.tripMemories, extra: trip.id);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.photo_library,
                                        size: 12, color: AppColors.accent),
                                    const SizedBox(width: 3),
                                    Text(
                                      '추억 ${_photoCounts[trip.id]}',
                                      style: AppTypography.caption.copyWith(
                                        color: AppColors.accent,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // 화살표
              const Padding(
                padding: EdgeInsets.only(right: AppDimens.spacing12),
                child: Icon(
                  Icons.chevron_right,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(TripStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spacing8,
        vertical: AppDimens.spacing4,
      ),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
      ),
      child: Text(
        _getStatusLabel(status),
        style: AppTypography.caption.copyWith(
          color: _getStatusColor(status),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.luggage_outlined,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: AppDimens.spacing16),
          Text(
            '저장된 여행이 없어요',
            style: AppTypography.body1.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppDimens.spacing16),
          OutlinedButton.icon(
            onPressed: () => context.push(AppRoutes.planInput),
            icon: const Icon(Icons.add),
            label: const Text('새 여행 계획하기'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(TripStatus status) {
    switch (status) {
      case TripStatus.upcoming:
        return AppColors.info;
      case TripStatus.ongoing:
        return AppColors.success;
      case TripStatus.completed:
        return AppColors.textSecondary;
    }
  }

  String _getStatusLabel(TripStatus status) {
    switch (status) {
      case TripStatus.upcoming:
        return '예정';
      case TripStatus.ongoing:
        return '진행중';
      case TripStatus.completed:
        return '완료';
    }
  }
}
