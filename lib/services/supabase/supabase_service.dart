import 'package:flutter/foundation.dart';
import '../../config/supabase_config.dart';
import '../../models/peptide.dart';
import '../../models/dose_history.dart';
import '../../models/schedule.dart';
import '../../models/peptide_calculation.dart';

class SupabaseService {
  final _client = SupabaseConfig.getClient();

  Future<Peptide?> insertPeptide(Peptide peptide) async {
    try {
      final response = await _client.from('peptides').insert(peptide.toJson()).select();
      if (response.isEmpty) return null;
      return Peptide.fromJson(response[0]);
    } catch (e) {
      debugPrint('Error inserting peptide: $e');
      return null;
    }
  }

  Future<Peptide?> getPeptide(String id) async {
    try {
      final response = await _client.from('peptides').select().eq('id', id);
      if (response.isEmpty) return null;
      return Peptide.fromJson(response[0]);
    } catch (e) {
      debugPrint('Error getting peptide: $e');
      return null;
    }
  }

  Future<List<Peptide>> getAllPeptides() async {
    try {
      final response = await _client
          .from('peptides')
          .select()
          .order('created_at', ascending: false);
      return response.map((item) => Peptide.fromJson(item)).toList();
    } catch (e) {
      debugPrint('Error getting peptides: $e');
      return [];
    }
  }

  Future<void> updatePeptide(Peptide peptide) async {
    try {
      await _client.from('peptides').update(peptide.toJson()).eq('id', peptide.id);
    } catch (e) {
      debugPrint('Error updating peptide: $e');
    }
  }

  Future<void> deletePeptide(String id) async {
    try {
      await _client.from('peptides').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting peptide: $e');
    }
  }

  Future<DoseHistory?> insertDose(DoseHistory dose) async {
    try {
      final response = await _client.from('doses').insert(dose.toJson()).select();
      if (response.isEmpty) return null;
      return DoseHistory.fromJson(response[0]);
    } catch (e) {
      debugPrint('Error inserting dose: $e');
      return null;
    }
  }

  Future<List<DoseHistory>> getDosesByPeptide(String peptideId) async {
    try {
      final response = await _client
          .from('doses')
          .select()
          .eq('peptide_id', peptideId)
          .order('taken_at', ascending: false);
      return response.map((item) => DoseHistory.fromJson(item)).toList();
    } catch (e) {
      debugPrint('Error getting doses: $e');
      return [];
    }
  }

  Future<void> updateDose(DoseHistory dose) async {
    try {
      await _client.from('doses').update(dose.toJson()).eq('id', dose.id);
    } catch (e) {
      debugPrint('Error updating dose: $e');
    }
  }

  Future<void> deleteDose(String id) async {
    try {
      await _client.from('doses').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting dose: $e');
    }
  }

  Future<PeptideSchedule?> insertSchedule(PeptideSchedule schedule) async {
    try {
      final response =
          await _client.from('peptide_schedules').insert(schedule.toJson()).select();
      if (response.isEmpty) return null;
      return PeptideSchedule.fromJson(response[0]);
    } catch (e) {
      debugPrint('Error inserting schedule: $e');
      return null;
    }
  }

  Future<List<PeptideSchedule>> getSchedulesByPeptide(String peptideId) async {
    try {
      final response = await _client
          .from('peptide_schedules')
          .select()
          .eq('peptide_id', peptideId);
      return response.map((item) => PeptideSchedule.fromJson(item)).toList();
    } catch (e) {
      debugPrint('Error getting schedules: $e');
      return [];
    }
  }

  Future<void> updateSchedule(PeptideSchedule schedule) async {
    try {
      await _client
          .from('peptide_schedules')
          .update(schedule.toJson())
          .eq('id', schedule.id);
    } catch (e) {
      debugPrint('Error updating schedule: $e');
    }
  }

  Future<PeptideCalculation?> insertCalculation(PeptideCalculation calculation) async {
    try {
      final response =
          await _client.from('calculations').insert(calculation.toJson()).select();
      if (response.isEmpty) return null;
      return PeptideCalculation.fromJson(response[0]);
    } catch (e) {
      debugPrint('Error inserting calculation: $e');
      return null;
    }
  }

  Future<List<PeptideCalculation>> getAllCalculations() async {
    try {
      final response = await _client
          .from('calculations')
          .select()
          .order('calculated_at', ascending: false);
      return response.map((item) => PeptideCalculation.fromJson(item)).toList();
    } catch (e) {
      debugPrint('Error getting calculations: $e');
      return [];
    }
  }
}
