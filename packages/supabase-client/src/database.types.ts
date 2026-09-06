export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.15"
  }
  graphql_public: {
    Tables: {
      [_ in never]: never
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      graphql: {
        Args: {
          extensions?: Json
          operationName?: string
          query?: string
          variables?: Json
        }
        Returns: Json
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
  public: {
    Tables: {
      abilities: {
        Row: {
          id: string
          order: number
        }
        Insert: {
          id: string
          order: number
        }
        Update: {
          id?: string
          order?: number
        }
        Relationships: []
      }
      alignments: {
        Row: {
          id: number
        }
        Insert: {
          id?: never
        }
        Update: {
          id?: never
        }
        Relationships: []
      }
      app_admins: {
        Row: {
          created_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          user_id?: string
        }
        Relationships: []
      }
      armor_properties: {
        Row: {
          ac_base: number
          ac_dex_bonus: string
          item_id: number
          stealth_disadvantage: boolean
          strength_requirement: number | null
        }
        Insert: {
          ac_base: number
          ac_dex_bonus: string
          item_id: number
          stealth_disadvantage?: boolean
          strength_requirement?: number | null
        }
        Update: {
          ac_base?: number
          ac_dex_bonus?: string
          item_id?: number
          stealth_disadvantage?: boolean
          strength_requirement?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "armor_properties_item_id_fkey"
            columns: ["item_id"]
            isOneToOne: true
            referencedRelation: "items"
            referencedColumns: ["id"]
          },
        ]
      }
      backgrounds: {
        Row: {
          equipment: Json
          id: number
          skill_proficiencies: Json
          tool_or_language_choices: Json
        }
        Insert: {
          equipment?: Json
          id?: never
          skill_proficiencies?: Json
          tool_or_language_choices?: Json
        }
        Update: {
          equipment?: Json
          id?: never
          skill_proficiencies?: Json
          tool_or_language_choices?: Json
        }
        Relationships: []
      }
      bug_reports: {
        Row: {
          app_version: string | null
          character_id: string | null
          created_at: string
          description: string
          error_message: string | null
          github_issue_number: number | null
          github_issue_url: string | null
          id: string
          platform: string | null
          reporter_id: string
          severity: string
          status: string
          title: string
        }
        Insert: {
          app_version?: string | null
          character_id?: string | null
          created_at?: string
          description: string
          error_message?: string | null
          github_issue_number?: number | null
          github_issue_url?: string | null
          id?: string
          platform?: string | null
          reporter_id: string
          severity: string
          status?: string
          title: string
        }
        Update: {
          app_version?: string | null
          character_id?: string | null
          created_at?: string
          description?: string
          error_message?: string | null
          github_issue_number?: number | null
          github_issue_url?: string | null
          id?: string
          platform?: string | null
          reporter_id?: string
          severity?: string
          status?: string
          title?: string
        }
        Relationships: [
          {
            foreignKeyName: "bug_reports_character_id_fkey"
            columns: ["character_id"]
            isOneToOne: false
            referencedRelation: "characters"
            referencedColumns: ["id"]
          },
        ]
      }
      character_ability_increases: {
        Row: {
          ability_id: string
          character_id: string
          id: string
          increase: number
          level: number
          source: string
        }
        Insert: {
          ability_id: string
          character_id: string
          id?: string
          increase: number
          level: number
          source: string
        }
        Update: {
          ability_id?: string
          character_id?: string
          id?: string
          increase?: number
          level?: number
          source?: string
        }
        Relationships: [
          {
            foreignKeyName: "character_ability_increases_ability_id_fkey"
            columns: ["ability_id"]
            isOneToOne: false
            referencedRelation: "abilities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "character_ability_increases_character_id_fkey"
            columns: ["character_id"]
            isOneToOne: false
            referencedRelation: "characters"
            referencedColumns: ["id"]
          },
        ]
      }
      character_ability_scores: {
        Row: {
          ability_id: string
          character_id: string
          score: number
        }
        Insert: {
          ability_id: string
          character_id: string
          score: number
        }
        Update: {
          ability_id?: string
          character_id?: string
          score?: number
        }
        Relationships: [
          {
            foreignKeyName: "character_ability_scores_ability_id_fkey"
            columns: ["ability_id"]
            isOneToOne: false
            referencedRelation: "abilities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "character_ability_scores_character_id_fkey"
            columns: ["character_id"]
            isOneToOne: false
            referencedRelation: "characters"
            referencedColumns: ["id"]
          },
        ]
      }
      character_campaigns: {
        Row: {
          character_id: string
          id: string
          joined_at: string
          role: string
          story_id: string
        }
        Insert: {
          character_id: string
          id?: string
          joined_at?: string
          role?: string
          story_id: string
        }
        Update: {
          character_id?: string
          id?: string
          joined_at?: string
          role?: string
          story_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "character_campaigns_character_id_fkey"
            columns: ["character_id"]
            isOneToOne: false
            referencedRelation: "characters"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "character_campaigns_story_id_fkey"
            columns: ["story_id"]
            isOneToOne: false
            referencedRelation: "stories"
            referencedColumns: ["id"]
          },
        ]
      }
      character_class_options: {
        Row: {
          character_id: string
          chosen_value: string
          class_feature_id: number
          id: string
          level: number
        }
        Insert: {
          character_id: string
          chosen_value: string
          class_feature_id: number
          id?: string
          level: number
        }
        Update: {
          character_id?: string
          chosen_value?: string
          class_feature_id?: number
          id?: string
          level?: number
        }
        Relationships: [
          {
            foreignKeyName: "character_class_options_character_id_fkey"
            columns: ["character_id"]
            isOneToOne: false
            referencedRelation: "characters"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "character_class_options_class_feature_id_fkey"
            columns: ["class_feature_id"]
            isOneToOne: false
            referencedRelation: "class_features"
            referencedColumns: ["id"]
          },
        ]
      }
      character_classes: {
        Row: {
          character_id: string
          class_id: number
          hit_dice_spent: number
          id: string
          is_primary: boolean
          level: number
          subclass_id: number | null
        }
        Insert: {
          character_id: string
          class_id: number
          hit_dice_spent?: number
          id?: string
          is_primary?: boolean
          level?: number
          subclass_id?: number | null
        }
        Update: {
          character_id?: string
          class_id?: number
          hit_dice_spent?: number
          id?: string
          is_primary?: boolean
          level?: number
          subclass_id?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "character_classes_character_id_fkey"
            columns: ["character_id"]
            isOneToOne: false
            referencedRelation: "characters"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "character_classes_class_id_fkey"
            columns: ["class_id"]
            isOneToOne: false
            referencedRelation: "classes"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "character_classes_subclass_id_fkey"
            columns: ["subclass_id"]
            isOneToOne: false
            referencedRelation: "subclasses"
            referencedColumns: ["id"]
          },
        ]
      }
      character_feats: {
        Row: {
          character_id: string
          feat_id: number
          level_taken: number
        }
        Insert: {
          character_id: string
          feat_id: number
          level_taken: number
        }
        Update: {
          character_id?: string
          feat_id?: number
          level_taken?: number
        }
        Relationships: [
          {
            foreignKeyName: "character_feats_character_id_fkey"
            columns: ["character_id"]
            isOneToOne: false
            referencedRelation: "characters"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "character_feats_feat_id_fkey"
            columns: ["feat_id"]
            isOneToOne: false
            referencedRelation: "feats"
            referencedColumns: ["id"]
          },
        ]
      }
      character_feature_uses: {
        Row: {
          character_id: string
          class_feature_id: number
          uses_remaining: number
        }
        Insert: {
          character_id: string
          class_feature_id: number
          uses_remaining?: number
        }
        Update: {
          character_id?: string
          class_feature_id?: number
          uses_remaining?: number
        }
        Relationships: [
          {
            foreignKeyName: "character_feature_uses_character_id_fkey"
            columns: ["character_id"]
            isOneToOne: false
            referencedRelation: "characters"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "character_feature_uses_class_feature_id_fkey"
            columns: ["class_feature_id"]
            isOneToOne: false
            referencedRelation: "class_features"
            referencedColumns: ["id"]
          },
        ]
      }
      character_inventory: {
        Row: {
          character_id: string
          custom_name: string | null
          equipped: boolean
          id: string
          item_id: number | null
          notes: string | null
          quantity: number
        }
        Insert: {
          character_id: string
          custom_name?: string | null
          equipped?: boolean
          id?: string
          item_id?: number | null
          notes?: string | null
          quantity?: number
        }
        Update: {
          character_id?: string
          custom_name?: string | null
          equipped?: boolean
          id?: string
          item_id?: number | null
          notes?: string | null
          quantity?: number
        }
        Relationships: [
          {
            foreignKeyName: "character_inventory_character_id_fkey"
            columns: ["character_id"]
            isOneToOne: false
            referencedRelation: "characters"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "character_inventory_item_id_fkey"
            columns: ["item_id"]
            isOneToOne: false
            referencedRelation: "items"
            referencedColumns: ["id"]
          },
        ]
      }
      character_invocations: {
        Row: {
          character_id: string
          invocation_id: number
        }
        Insert: {
          character_id: string
          invocation_id: number
        }
        Update: {
          character_id?: string
          invocation_id?: number
        }
        Relationships: [
          {
            foreignKeyName: "character_invocations_character_id_fkey"
            columns: ["character_id"]
            isOneToOne: false
            referencedRelation: "characters"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "character_invocations_invocation_id_fkey"
            columns: ["invocation_id"]
            isOneToOne: false
            referencedRelation: "invocations"
            referencedColumns: ["id"]
          },
        ]
      }
      character_languages: {
        Row: {
          character_id: string
          language_id: number
        }
        Insert: {
          character_id: string
          language_id: number
        }
        Update: {
          character_id?: string
          language_id?: number
        }
        Relationships: [
          {
            foreignKeyName: "character_languages_character_id_fkey"
            columns: ["character_id"]
            isOneToOne: false
            referencedRelation: "characters"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "character_languages_language_id_fkey"
            columns: ["language_id"]
            isOneToOne: false
            referencedRelation: "languages"
            referencedColumns: ["id"]
          },
        ]
      }
      character_level_hp: {
        Row: {
          character_id: string
          created_at: string
          hp_rolled: number
          id: string
          level: number
          method: string
        }
        Insert: {
          character_id: string
          created_at?: string
          hp_rolled: number
          id?: string
          level: number
          method: string
        }
        Update: {
          character_id?: string
          created_at?: string
          hp_rolled?: number
          id?: string
          level?: number
          method?: string
        }
        Relationships: [
          {
            foreignKeyName: "character_level_hp_character_id_fkey"
            columns: ["character_id"]
            isOneToOne: false
            referencedRelation: "characters"
            referencedColumns: ["id"]
          },
        ]
      }
      character_pact_slots: {
        Row: {
          character_id: string
          slot_level: number
          slots_total: number
          slots_used: number
        }
        Insert: {
          character_id: string
          slot_level: number
          slots_total?: number
          slots_used?: number
        }
        Update: {
          character_id?: string
          slot_level?: number
          slots_total?: number
          slots_used?: number
        }
        Relationships: [
          {
            foreignKeyName: "character_pact_slots_character_id_fkey"
            columns: ["character_id"]
            isOneToOne: true
            referencedRelation: "characters"
            referencedColumns: ["id"]
          },
        ]
      }
      character_skill_proficiencies: {
        Row: {
          character_id: string
          proficiency: string
          skill_id: number
        }
        Insert: {
          character_id: string
          proficiency?: string
          skill_id: number
        }
        Update: {
          character_id?: string
          proficiency?: string
          skill_id?: number
        }
        Relationships: [
          {
            foreignKeyName: "character_skill_proficiencies_character_id_fkey"
            columns: ["character_id"]
            isOneToOne: false
            referencedRelation: "characters"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "character_skill_proficiencies_skill_id_fkey"
            columns: ["skill_id"]
            isOneToOne: false
            referencedRelation: "skills"
            referencedColumns: ["id"]
          },
        ]
      }
      character_spell_slots: {
        Row: {
          character_id: string
          slot_level: number
          slots_total: number
          slots_used: number
        }
        Insert: {
          character_id: string
          slot_level: number
          slots_total?: number
          slots_used?: number
        }
        Update: {
          character_id?: string
          slot_level?: number
          slots_total?: number
          slots_used?: number
        }
        Relationships: [
          {
            foreignKeyName: "character_spell_slots_character_id_fkey"
            columns: ["character_id"]
            isOneToOne: false
            referencedRelation: "characters"
            referencedColumns: ["id"]
          },
        ]
      }
      character_spells: {
        Row: {
          character_id: string
          id: string
          source_class_id: number | null
          spell_id: number
          status: string
        }
        Insert: {
          character_id: string
          id?: string
          source_class_id?: number | null
          spell_id: number
          status: string
        }
        Update: {
          character_id?: string
          id?: string
          source_class_id?: number | null
          spell_id?: number
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "character_spells_character_id_fkey"
            columns: ["character_id"]
            isOneToOne: false
            referencedRelation: "characters"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "character_spells_source_class_id_fkey"
            columns: ["source_class_id"]
            isOneToOne: false
            referencedRelation: "classes"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "character_spells_spell_id_fkey"
            columns: ["spell_id"]
            isOneToOne: false
            referencedRelation: "spells"
            referencedColumns: ["id"]
          },
        ]
      }
      character_tool_proficiencies: {
        Row: {
          character_id: string
          custom_text: string | null
          id: string
          tool_id: number | null
        }
        Insert: {
          character_id: string
          custom_text?: string | null
          id?: string
          tool_id?: number | null
        }
        Update: {
          character_id?: string
          custom_text?: string | null
          id?: string
          tool_id?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "character_tool_proficiencies_character_id_fkey"
            columns: ["character_id"]
            isOneToOne: false
            referencedRelation: "characters"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "character_tool_proficiencies_tool_id_fkey"
            columns: ["tool_id"]
            isOneToOne: false
            referencedRelation: "tools"
            referencedColumns: ["id"]
          },
        ]
      }
      characters: {
        Row: {
          age: string | null
          alignment_id: number | null
          allies_text: string
          appearance_text: string
          background_custom_text: string | null
          background_id: number | null
          backstory_text: string
          bonds_text: string
          created_at: string
          currency_cp: number
          currency_ep: number
          currency_gp: number
          currency_pp: number
          currency_sp: number
          current_hp: number
          eyes: string | null
          features_text: string
          flaws_text: string
          hair: string | null
          height: string | null
          id: string
          ideals_text: string
          last_long_rest_at: string | null
          max_hp: number
          name: string
          owner_id: string
          portrait_url: string | null
          race_custom_text: string | null
          race_id: number | null
          sexe: string | null
          skin: string | null
          subrace_id: number | null
          temporary_hp: number
          traits_text: string
          treasure_text: string
          updated_at: string
          weight: string | null
          xp: number
        }
        Insert: {
          age?: string | null
          alignment_id?: number | null
          allies_text?: string
          appearance_text?: string
          background_custom_text?: string | null
          background_id?: number | null
          backstory_text?: string
          bonds_text?: string
          created_at?: string
          currency_cp?: number
          currency_ep?: number
          currency_gp?: number
          currency_pp?: number
          currency_sp?: number
          current_hp?: number
          eyes?: string | null
          features_text?: string
          flaws_text?: string
          hair?: string | null
          height?: string | null
          id?: string
          ideals_text?: string
          last_long_rest_at?: string | null
          max_hp?: number
          name?: string
          owner_id: string
          portrait_url?: string | null
          race_custom_text?: string | null
          race_id?: number | null
          sexe?: string | null
          skin?: string | null
          subrace_id?: number | null
          temporary_hp?: number
          traits_text?: string
          treasure_text?: string
          updated_at?: string
          weight?: string | null
          xp?: number
        }
        Update: {
          age?: string | null
          alignment_id?: number | null
          allies_text?: string
          appearance_text?: string
          background_custom_text?: string | null
          background_id?: number | null
          backstory_text?: string
          bonds_text?: string
          created_at?: string
          currency_cp?: number
          currency_ep?: number
          currency_gp?: number
          currency_pp?: number
          currency_sp?: number
          current_hp?: number
          eyes?: string | null
          features_text?: string
          flaws_text?: string
          hair?: string | null
          height?: string | null
          id?: string
          ideals_text?: string
          last_long_rest_at?: string | null
          max_hp?: number
          name?: string
          owner_id?: string
          portrait_url?: string | null
          race_custom_text?: string | null
          race_id?: number | null
          sexe?: string | null
          skin?: string | null
          subrace_id?: number | null
          temporary_hp?: number
          traits_text?: string
          treasure_text?: string
          updated_at?: string
          weight?: string | null
          xp?: number
        }
        Relationships: [
          {
            foreignKeyName: "characters_alignment_id_fkey"
            columns: ["alignment_id"]
            isOneToOne: false
            referencedRelation: "alignments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "characters_background_id_fkey"
            columns: ["background_id"]
            isOneToOne: false
            referencedRelation: "backgrounds"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "characters_race_id_fkey"
            columns: ["race_id"]
            isOneToOne: false
            referencedRelation: "races"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "characters_subrace_id_fkey"
            columns: ["subrace_id"]
            isOneToOne: false
            referencedRelation: "subraces"
            referencedColumns: ["id"]
          },
        ]
      }
      class_features: {
        Row: {
          choice_type: string | null
          class_id: number | null
          id: number
          level: number
          subclass_id: number | null
          uses_per_rest: Json | null
        }
        Insert: {
          choice_type?: string | null
          class_id?: number | null
          id?: never
          level: number
          subclass_id?: number | null
          uses_per_rest?: Json | null
        }
        Update: {
          choice_type?: string | null
          class_id?: number | null
          id?: never
          level?: number
          subclass_id?: number | null
          uses_per_rest?: Json | null
        }
        Relationships: [
          {
            foreignKeyName: "class_features_class_id_fkey"
            columns: ["class_id"]
            isOneToOne: false
            referencedRelation: "classes"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "class_features_subclass_id_fkey"
            columns: ["subclass_id"]
            isOneToOne: false
            referencedRelation: "subclasses"
            referencedColumns: ["id"]
          },
        ]
      }
      classes: {
        Row: {
          armor_proficiencies: Json
          hit_die: number
          id: number
          primary_abilities: Json
          saving_throw_proficiencies: Json
          skill_choices: Json
          source: string | null
          tool_proficiencies: Json
          weapon_proficiencies: Json
        }
        Insert: {
          armor_proficiencies?: Json
          hit_die: number
          id?: never
          primary_abilities?: Json
          saving_throw_proficiencies?: Json
          skill_choices?: Json
          source?: string | null
          tool_proficiencies?: Json
          weapon_proficiencies?: Json
        }
        Update: {
          armor_proficiencies?: Json
          hit_die?: number
          id?: never
          primary_abilities?: Json
          saving_throw_proficiencies?: Json
          skill_choices?: Json
          source?: string | null
          tool_proficiencies?: Json
          weapon_proficiencies?: Json
        }
        Relationships: []
      }
      codex_entries: {
        Row: {
          attributes: Json
          category: string
          content: string
          created_at: string
          id: string
          name: string
          story_id: string
          summary: string
          updated_at: string
          user_id: string
        }
        Insert: {
          attributes?: Json
          category: string
          content?: string
          created_at?: string
          id?: string
          name: string
          story_id: string
          summary?: string
          updated_at?: string
          user_id: string
        }
        Update: {
          attributes?: Json
          category?: string
          content?: string
          created_at?: string
          id?: string
          name?: string
          story_id?: string
          summary?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "codex_entries_story_id_fkey"
            columns: ["story_id"]
            isOneToOne: false
            referencedRelation: "stories"
            referencedColumns: ["id"]
          },
        ]
      }
      equipment_packs: {
        Row: {
          contents: Json
          id: number
        }
        Insert: {
          contents?: Json
          id?: never
        }
        Update: {
          contents?: Json
          id?: never
        }
        Relationships: []
      }
      feats: {
        Row: {
          id: number
          prerequisites: Json
        }
        Insert: {
          id?: never
          prerequisites?: Json
        }
        Update: {
          id?: never
          prerequisites?: Json
        }
        Relationships: []
      }
      invocations: {
        Row: {
          id: number
          prerequisites: Json
        }
        Insert: {
          id?: never
          prerequisites?: Json
        }
        Update: {
          id?: never
          prerequisites?: Json
        }
        Relationships: []
      }
      items: {
        Row: {
          category: string
          consumable: boolean
          cost: Json | null
          id: number
          rarity: string | null
          requires_attunement: boolean
          source: string | null
          weight: number | null
        }
        Insert: {
          category: string
          consumable?: boolean
          cost?: Json | null
          id?: never
          rarity?: string | null
          requires_attunement?: boolean
          source?: string | null
          weight?: number | null
        }
        Update: {
          category?: string
          consumable?: boolean
          cost?: Json | null
          id?: never
          rarity?: string | null
          requires_attunement?: boolean
          source?: string | null
          weight?: number | null
        }
        Relationships: []
      }
      languages: {
        Row: {
          id: number
          type: string
        }
        Insert: {
          id?: never
          type: string
        }
        Update: {
          id?: never
          type?: string
        }
        Relationships: []
      }
      notification_preferences: {
        Row: {
          email_digest_enabled: boolean
          last_email_digest_sent_at: string | null
          last_rest_reminder_sent_at: string | null
          push_access_revoked: boolean
          push_enabled: boolean
          push_rest_reminder: boolean
          updated_at: string
          user_id: string
        }
        Insert: {
          email_digest_enabled?: boolean
          last_email_digest_sent_at?: string | null
          last_rest_reminder_sent_at?: string | null
          push_access_revoked?: boolean
          push_enabled?: boolean
          push_rest_reminder?: boolean
          updated_at?: string
          user_id: string
        }
        Update: {
          email_digest_enabled?: boolean
          last_email_digest_sent_at?: string | null
          last_rest_reminder_sent_at?: string | null
          push_access_revoked?: boolean
          push_enabled?: boolean
          push_rest_reminder?: boolean
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      races: {
        Row: {
          ability_bonuses: Json
          id: number
          languages: Json
          size: string | null
          source: string | null
          speed: number | null
          traits: Json
        }
        Insert: {
          ability_bonuses?: Json
          id?: never
          languages?: Json
          size?: string | null
          source?: string | null
          speed?: number | null
          traits?: Json
        }
        Update: {
          ability_bonuses?: Json
          id?: never
          languages?: Json
          size?: string | null
          source?: string | null
          speed?: number | null
          traits?: Json
        }
        Relationships: []
      }
      skills: {
        Row: {
          ability_id: string
          id: number
        }
        Insert: {
          ability_id: string
          id?: never
        }
        Update: {
          ability_id?: string
          id?: never
        }
        Relationships: [
          {
            foreignKeyName: "skills_ability_id_fkey"
            columns: ["ability_id"]
            isOneToOne: false
            referencedRelation: "abilities"
            referencedColumns: ["id"]
          },
        ]
      }
      spell_classes: {
        Row: {
          class_id: number
          spell_id: number
        }
        Insert: {
          class_id: number
          spell_id: number
        }
        Update: {
          class_id?: number
          spell_id?: number
        }
        Relationships: [
          {
            foreignKeyName: "spell_classes_class_id_fkey"
            columns: ["class_id"]
            isOneToOne: false
            referencedRelation: "classes"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "spell_classes_spell_id_fkey"
            columns: ["spell_id"]
            isOneToOne: false
            referencedRelation: "spells"
            referencedColumns: ["id"]
          },
        ]
      }
      spells: {
        Row: {
          casting_time: string | null
          components: Json
          concentration: boolean
          duration: string | null
          id: number
          level: number
          range: string | null
          ritual: boolean
          school: string | null
          source: string | null
        }
        Insert: {
          casting_time?: string | null
          components?: Json
          concentration?: boolean
          duration?: string | null
          id?: never
          level: number
          range?: string | null
          ritual?: boolean
          school?: string | null
          source?: string | null
        }
        Update: {
          casting_time?: string | null
          components?: Json
          concentration?: boolean
          duration?: string | null
          id?: never
          level?: number
          range?: string | null
          ritual?: boolean
          school?: string | null
          source?: string | null
        }
        Relationships: []
      }
      stories: {
        Row: {
          content: string
          cover_image_path: string | null
          created_at: string
          id: string
          invite_code: string | null
          invite_code_enabled: boolean
          published: boolean
          title: string
          updated_at: string
          user_id: string
        }
        Insert: {
          content?: string
          cover_image_path?: string | null
          created_at?: string
          id?: string
          invite_code?: string | null
          invite_code_enabled?: boolean
          published?: boolean
          title: string
          updated_at?: string
          user_id: string
        }
        Update: {
          content?: string
          cover_image_path?: string | null
          created_at?: string
          id?: string
          invite_code?: string | null
          invite_code_enabled?: boolean
          published?: boolean
          title?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      subclasses: {
        Row: {
          available_from_level: number
          class_id: number
          id: number
        }
        Insert: {
          available_from_level: number
          class_id: number
          id?: never
        }
        Update: {
          available_from_level?: number
          class_id?: number
          id?: never
        }
        Relationships: [
          {
            foreignKeyName: "subclasses_class_id_fkey"
            columns: ["class_id"]
            isOneToOne: false
            referencedRelation: "classes"
            referencedColumns: ["id"]
          },
        ]
      }
      subraces: {
        Row: {
          ability_bonuses: Json
          id: number
          race_id: number
          traits: Json
        }
        Insert: {
          ability_bonuses?: Json
          id?: never
          race_id: number
          traits?: Json
        }
        Update: {
          ability_bonuses?: Json
          id?: never
          race_id?: number
          traits?: Json
        }
        Relationships: [
          {
            foreignKeyName: "subraces_race_id_fkey"
            columns: ["race_id"]
            isOneToOne: false
            referencedRelation: "races"
            referencedColumns: ["id"]
          },
        ]
      }
      tools: {
        Row: {
          category: string
          id: number
        }
        Insert: {
          category: string
          id?: never
        }
        Update: {
          category?: string
          id?: never
        }
        Relationships: []
      }
      translations: {
        Row: {
          entity_id: string
          entity_type: string
          field_name: string
          id: string
          locale: string
          value: string
        }
        Insert: {
          entity_id: string
          entity_type: string
          field_name: string
          id?: string
          locale: string
          value: string
        }
        Update: {
          entity_id?: string
          entity_type?: string
          field_name?: string
          id?: string
          locale?: string
          value?: string
        }
        Relationships: []
      }
      user_push_tokens: {
        Row: {
          platform: string
          token: string
          updated_at: string
          user_id: string
        }
        Insert: {
          platform: string
          token: string
          updated_at?: string
          user_id: string
        }
        Update: {
          platform?: string
          token?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      weapon_properties: {
        Row: {
          damage_dice: string | null
          damage_type: string | null
          item_id: number
          properties: Json
          range: Json | null
        }
        Insert: {
          damage_dice?: string | null
          damage_type?: string | null
          item_id: number
          properties?: Json
          range?: Json | null
        }
        Update: {
          damage_dice?: string | null
          damage_type?: string | null
          item_id?: number
          properties?: Json
          range?: Json | null
        }
        Relationships: [
          {
            foreignKeyName: "weapon_properties_item_id_fkey"
            columns: ["item_id"]
            isOneToOne: true
            referencedRelation: "items"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      character_owner_can_read_joined_story: {
        Args: { p_story_id: string }
        Returns: boolean
      }
      claim_push_token: {
        Args: { p_platform: string; p_token: string }
        Returns: undefined
      }
      is_admin: { Args: never; Returns: boolean }
      owns_character: { Args: { p_character_id: string }; Returns: boolean }
      stories_gm_display_name: {
        Args: { story: Database["public"]["Tables"]["stories"]["Row"] }
        Returns: string
      }
      story_owner_can_read_character: {
        Args: { p_character_id: string }
        Returns: boolean
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  graphql_public: {
    Enums: {},
  },
  public: {
    Enums: {},
  },
} as const

