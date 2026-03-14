-- =============================================================
-- Telli Dialog Database Schema
-- Combined migrations for telli_dialog_db
-- Generated from packages/shared/migrations/
-- =============================================================

-- Enable required extensions first
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 0000_loud_vapor.sql
DO $$ BEGIN
 CREATE TYPE "public"."character_access_level" AS ENUM('private', 'school', 'global');
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
DO $$ BEGIN
 CREATE TYPE "public"."conversation_role" AS ENUM('user', 'assistant', 'system', 'tool');
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
DO $$ BEGIN
 CREATE TYPE "public"."llm_model_type" AS ENUM('text', 'image', 'fc');
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
DO $$ BEGIN
 CREATE TYPE "public"."user_school_role" AS ENUM('student', 'teacher');
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
CREATE TABLE IF NOT EXISTS "character" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"name" text NOT NULL,
	"description" text,
	"learning_context" text,
	"specifications" text,
	"competence" text,
	"restrictions" text,
	"picture_id" text,
	"access_level" "character_access_level" DEFAULT 'private' NOT NULL,
	"school_id" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE IF NOT EXISTS "conversation_message" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"content" text NOT NULL,
	"conversation_id" uuid NOT NULL,
	"model_name" text,
	"user_id" uuid,
	"role" "conversation_role" NOT NULL,
	"order_number" integer NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone
);
CREATE TABLE IF NOT EXISTS "conversation" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"name" text,
	"user_id" uuid NOT NULL,
	"character_id" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone
);
CREATE TABLE IF NOT EXISTS "conversation_usage_tracking" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"model_id" uuid NOT NULL,
	"conversation_id" uuid NOT NULL,
	"user_id" uuid NOT NULL,
	"completion_tokens" integer NOT NULL,
	"prompt_tokens" integer NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE IF NOT EXISTS "federal_state_llm_model_mapping" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"federal_state_id" text NOT NULL,
	"llm_model_id" uuid NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "federal_state_llm_model_mapping_federal_state_id_llm_model_id_unique" UNIQUE("federal_state_id","llm_model_id")
);
CREATE TABLE IF NOT EXISTS "federal_state" (
	"id" text PRIMARY KEY NOT NULL,
	"teacher_price_limit" integer DEFAULT 500 NOT NULL,
	"student_price_limit" integer DEFAULT 200 NOT NULL,
	"encrypted_api_key" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE IF NOT EXISTS "llm_model" (
	"id" uuid PRIMARY KEY NOT NULL,
	"owner" text NOT NULL,
	"name" text NOT NULL,
	"display_name" text NOT NULL,
	"description" text DEFAULT '' NOT NULL,
	"price_metada" json NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "llm_model_owner_name_unique" UNIQUE("owner","name")
);
CREATE TABLE IF NOT EXISTS "school" (
	"id" text PRIMARY KEY NOT NULL,
	"federal_state_id" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE IF NOT EXISTS "shared_school_conversation" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"name" text NOT NULL,
	"description" text DEFAULT '' NOT NULL,
	"model_id" uuid NOT NULL,
	"user_id" uuid NOT NULL,
	"school_type" text DEFAULT '' NOT NULL,
	"grade_level" text DEFAULT '' NOT NULL,
	"subject" text DEFAULT '' NOT NULL,
	"learning_context" text DEFAULT '' NOT NULL,
	"specification" text DEFAULT '' NOT NULL,
	"restrictions" text DEFAULT '' NOT NULL,
	"intelligence_points_limit" integer,
	"max_usage_time_limit" integer,
	"invite_code" text,
	"started_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "shared_school_conversation_invite_code_unique" UNIQUE("invite_code")
);
CREATE TABLE IF NOT EXISTS "shared_school_conversation_usage_tracking" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"model_id" uuid NOT NULL,
	"shared_school_conversation_id" uuid NOT NULL,
	"user_id" uuid NOT NULL,
	"completion_tokens" integer NOT NULL,
	"prompt_tokens" integer NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE IF NOT EXISTS "user_school_mapping" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"school_id" text NOT NULL,
	"role" "user_school_role" NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "user_school_mapping_user_id_school_id_unique" UNIQUE("user_id","school_id")
);
CREATE TABLE IF NOT EXISTS "user_entity" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"first_name" text NOT NULL,
	"last_name" text NOT NULL,
	"email" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "user_entity_email_unique" UNIQUE("email")
);
DO $$ BEGIN
 ALTER TABLE "character" ADD CONSTRAINT "character_user_id_user_entity_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user_entity"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
DO $$ BEGIN
 ALTER TABLE "character" ADD CONSTRAINT "character_school_id_school_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."school"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
DO $$ BEGIN
 ALTER TABLE "conversation_message" ADD CONSTRAINT "conversation_message_conversation_id_conversation_id_fk" FOREIGN KEY ("conversation_id") REFERENCES "public"."conversation"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
DO $$ BEGIN
 ALTER TABLE "conversation_message" ADD CONSTRAINT "conversation_message_user_id_user_entity_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user_entity"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
DO $$ BEGIN
 ALTER TABLE "conversation" ADD CONSTRAINT "conversation_user_id_user_entity_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user_entity"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
DO $$ BEGIN
 ALTER TABLE "conversation" ADD CONSTRAINT "conversation_character_id_character_id_fk" FOREIGN KEY ("character_id") REFERENCES "public"."character"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
DO $$ BEGIN
 ALTER TABLE "conversation_usage_tracking" ADD CONSTRAINT "conversation_usage_tracking_model_id_llm_model_id_fk" FOREIGN KEY ("model_id") REFERENCES "public"."llm_model"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
DO $$ BEGIN
 ALTER TABLE "federal_state_llm_model_mapping" ADD CONSTRAINT "federal_state_llm_model_mapping_federal_state_id_federal_state_id_fk" FOREIGN KEY ("federal_state_id") REFERENCES "public"."federal_state"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
DO $$ BEGIN
 ALTER TABLE "federal_state_llm_model_mapping" ADD CONSTRAINT "federal_state_llm_model_mapping_llm_model_id_llm_model_id_fk" FOREIGN KEY ("llm_model_id") REFERENCES "public"."llm_model"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
DO $$ BEGIN
 ALTER TABLE "school" ADD CONSTRAINT "school_federal_state_id_federal_state_id_fk" FOREIGN KEY ("federal_state_id") REFERENCES "public"."federal_state"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
DO $$ BEGIN
 ALTER TABLE "shared_school_conversation" ADD CONSTRAINT "shared_school_conversation_model_id_llm_model_id_fk" FOREIGN KEY ("model_id") REFERENCES "public"."llm_model"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
DO $$ BEGIN
 ALTER TABLE "shared_school_conversation" ADD CONSTRAINT "shared_school_conversation_user_id_user_entity_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user_entity"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
DO $$ BEGIN
 ALTER TABLE "shared_school_conversation_usage_tracking" ADD CONSTRAINT "shared_school_conversation_usage_tracking_model_id_llm_model_id_fk" FOREIGN KEY ("model_id") REFERENCES "public"."llm_model"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
DO $$ BEGIN
 ALTER TABLE "user_school_mapping" ADD CONSTRAINT "user_school_mapping_user_id_user_entity_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user_entity"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
DO $$ BEGIN
 ALTER TABLE "user_school_mapping" ADD CONSTRAINT "user_school_mapping_school_id_school_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."school"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;

-- 0001_pretty_husk.sql
CREATE TABLE IF NOT EXISTS "shared_character_chat_usage_tracking" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"model_id" uuid NOT NULL,
	"character_id" uuid NOT NULL,
	"user_id" uuid NOT NULL,
	"completion_tokens" integer NOT NULL,
	"prompt_tokens" integer NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
UPDATE "character" SET "description" = '' WHERE "description" IS NULL;
UPDATE "character" SET "learning_context" = '' WHERE "learning_context" IS NULL;
UPDATE "character" SET "competence" = '' WHERE "competence" IS NULL;
ALTER TABLE "character" ALTER COLUMN "description" SET DEFAULT '';
ALTER TABLE "character" ALTER COLUMN "description" SET NOT NULL;
ALTER TABLE "character" ALTER COLUMN "learning_context" SET DEFAULT '';
ALTER TABLE "character" ALTER COLUMN "learning_context" SET NOT NULL;
ALTER TABLE "character" ALTER COLUMN "competence" SET DEFAULT '';
ALTER TABLE "character" ALTER COLUMN "competence" SET NOT NULL;
ALTER TABLE "character" ADD COLUMN IF NOT EXISTS "model_id" uuid NOT NULL;
ALTER TABLE "character" ADD COLUMN IF NOT EXISTS "school_type" text DEFAULT '' NOT NULL;
ALTER TABLE "character" ADD COLUMN IF NOT EXISTS "grade_level" text DEFAULT '' NOT NULL;
ALTER TABLE "character" ADD COLUMN IF NOT EXISTS "subject" text DEFAULT '' NOT NULL;
ALTER TABLE "character" ADD COLUMN IF NOT EXISTS "intelligence_points_limit" integer;
ALTER TABLE "character" ADD COLUMN IF NOT EXISTS "max_usage_time_limit" integer;
ALTER TABLE "character" ADD COLUMN IF NOT EXISTS "invite_code" text;
ALTER TABLE "character" ADD COLUMN IF NOT EXISTS "started_at" timestamp with time zone;
ALTER TABLE "shared_character_chat_usage_tracking" ADD CONSTRAINT "shared_character_chat_usage_tracking_model_id_llm_model_id_fk" FOREIGN KEY ("model_id") REFERENCES "public"."llm_model"("id") ON DELETE no action ON UPDATE no action;
ALTER TABLE "character" ADD CONSTRAINT "character_model_id_llm_model_id_fk" FOREIGN KEY ("model_id") REFERENCES "public"."llm_model"("id") ON DELETE no action ON UPDATE no action;
ALTER TABLE "character" ADD CONSTRAINT "character_invite_code_unique" UNIQUE("invite_code");

-- 0002_complex_white_queen.sql
CREATE TABLE IF NOT EXISTS "custom_gpt" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"name" text NOT NULL,
	"system_prompt" text NOT NULL,
	"user_id" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
ALTER TABLE "conversation" ADD COLUMN IF NOT EXISTS "custom_gpt_id" uuid;
ALTER TABLE "custom_gpt" ADD CONSTRAINT "custom_gpt_user_id_user_entity_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user_entity"("id") ON DELETE no action ON UPDATE no action;
ALTER TABLE "conversation" ADD CONSTRAINT "conversation_custom_gpt_id_custom_gpt_id_fk" FOREIGN KEY ("custom_gpt_id") REFERENCES "public"."custom_gpt"("id") ON DELETE no action ON UPDATE no action;

-- 0003_striped_tarot.sql
ALTER TABLE "federal_state" ADD COLUMN IF NOT EXISTS "mandatory_certification_teacher" boolean DEFAULT false;
ALTER TABLE "federal_state" ADD COLUMN IF NOT EXISTS "chat_storage_time" integer DEFAULT 120 NOT NULL;
ALTER TABLE "federal_state" ADD COLUMN IF NOT EXISTS "support_contact" text;
ALTER TABLE "federal_state" ADD COLUMN IF NOT EXISTS "training_link" text;
ALTER TABLE "federal_state" ADD COLUMN IF NOT EXISTS "student_access" boolean DEFAULT true NOT NULL;

-- 0004_loose_thunderbolt.sql
ALTER TABLE "user_entity" ADD COLUMN IF NOT EXISTS "versionAcceptedConditions" integer;

-- 0005_rapid_wind_dancer.sql
ALTER TABLE "user_entity" ADD COLUMN IF NOT EXISTS "last_used_model" text;

-- 0006_stiff_eternity.sql
CREATE TABLE IF NOT EXISTS "conversation_message_file_mapping" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"fileId" text NOT NULL,
	"conversationMessageId" uuid NOT NULL,
	"conversationId" uuid NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "conversation_message_file_mapping_conversationId_fileId_unique" UNIQUE("conversationId","fileId")
);
CREATE TABLE IF NOT EXISTS "file_table" (
	"id" text PRIMARY KEY NOT NULL,
	"name" text NOT NULL,
	"size" integer NOT NULL,
	"type" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
ALTER TABLE "conversation_message_file_mapping" ADD CONSTRAINT "conversation_message_file_mapping_fileId_file_table_id_fk" FOREIGN KEY ("fileId") REFERENCES "public"."file_table"("id") ON DELETE no action ON UPDATE no action;
ALTER TABLE "conversation_message_file_mapping" ADD CONSTRAINT "conversation_message_file_mapping_conversationMessageId_conversation_message_id_fk" FOREIGN KEY ("conversationMessageId") REFERENCES "public"."conversation_message"("id") ON DELETE no action ON UPDATE no action;
ALTER TABLE "conversation_message_file_mapping" ADD CONSTRAINT "conversation_message_file_mapping_conversationId_conversation_id_fk" FOREIGN KEY ("conversationId") REFERENCES "public"."conversation"("id") ON DELETE no action ON UPDATE no action;

-- 0007_mean_pyro.sql
ALTER TABLE "custom_gpt" ADD COLUMN IF NOT EXISTS "school_id" text;
ALTER TABLE "custom_gpt" ADD COLUMN IF NOT EXISTS "access_level" character_access_level DEFAULT 'private' NOT NULL;
ALTER TABLE "custom_gpt" ADD COLUMN IF NOT EXISTS "picture_id" text;
ALTER TABLE "custom_gpt" ADD COLUMN IF NOT EXISTS "description" text;
ALTER TABLE "custom_gpt" ADD COLUMN IF NOT EXISTS "specification" text;
ALTER TABLE "custom_gpt" ADD COLUMN IF NOT EXISTS "prompt_suggestions" text[] DEFAULT '{}'::text[] NOT NULL;
ALTER TABLE "custom_gpt" ADD CONSTRAINT "custom_gpt_school_id_school_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."school"("id") ON DELETE no action ON UPDATE no action;

-- 0008_amusing_ultimo.sql
CREATE TABLE IF NOT EXISTS "shared_character_conversation" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"character_id" uuid NOT NULL,
	"user_id" uuid NOT NULL,
	"intelligence_points_limit" integer,
	"max_usage_time_limit" integer,
	"invite_code" text,
	"started_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "shared_character_conversation_invite_code_unique" UNIQUE("invite_code")
);
ALTER TABLE "character" ALTER COLUMN "school_type" DROP NOT NULL;
ALTER TABLE "character" ALTER COLUMN "grade_level" DROP NOT NULL;
ALTER TABLE "character" ALTER COLUMN "subject" DROP NOT NULL;
ALTER TABLE "federal_state" ADD COLUMN IF NOT EXISTS "enable_characters" boolean DEFAULT true NOT NULL;
ALTER TABLE "federal_state" ADD COLUMN IF NOT EXISTS "enable_shared_chats" boolean DEFAULT true NOT NULL;
ALTER TABLE "federal_state" ADD COLUMN IF NOT EXISTS "enable_custom_gpts" boolean DEFAULT true NOT NULL;
ALTER TABLE "shared_character_conversation" ADD CONSTRAINT "shared_character_conversation_user_id_user_entity_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user_entity"("id") ON DELETE no action ON UPDATE no action;

-- 0009_violet_power_pack.sql
ALTER TABLE "shared_character_conversation" ADD CONSTRAINT "shared_character_conversation_character_id_user_id_unique" UNIQUE("character_id","user_id");

-- 0010_nervous_cardiac.sql
ALTER TABLE "character" ALTER COLUMN "school_type" DROP DEFAULT;
ALTER TABLE "character" ALTER COLUMN "grade_level" DROP DEFAULT;
ALTER TABLE "character" ALTER COLUMN "subject" DROP DEFAULT;
ALTER TABLE "shared_school_conversation" ALTER COLUMN "specification" DROP DEFAULT;
ALTER TABLE "shared_school_conversation" ALTER COLUMN "specification" DROP NOT NULL;
ALTER TABLE "shared_school_conversation" ALTER COLUMN "restrictions" DROP DEFAULT;
ALTER TABLE "shared_school_conversation" ALTER COLUMN "restrictions" DROP NOT NULL;

-- 0011_yielding_hercules.sql
CREATE TABLE IF NOT EXISTS "character_file_mapping" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"file_id" text NOT NULL,
	"character_id" uuid NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "character_file_mapping_character_id_file_id_unique" UNIQUE("character_id","file_id")
);
CREATE TABLE IF NOT EXISTS "custom_gpt_file_mapping" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"file_id" text NOT NULL,
	"custom_gpt_id" uuid NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "custom_gpt_file_mapping_custom_gpt_id_file_id_unique" UNIQUE("custom_gpt_id","file_id")
);
CREATE TABLE IF NOT EXISTS "shared_conversation_file_mapping" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"fileId" text NOT NULL,
	"shared_school_conversation_id" uuid NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "shared_conversation_file_mapping_shared_school_conversation_id_fileId_unique" UNIQUE("shared_school_conversation_id","fileId")
);
ALTER TABLE "character_file_mapping" ADD CONSTRAINT "character_file_mapping_file_id_file_table_id_fk" FOREIGN KEY ("file_id") REFERENCES "public"."file_table"("id") ON DELETE no action ON UPDATE no action;
ALTER TABLE "character_file_mapping" ADD CONSTRAINT "character_file_mapping_character_id_character_id_fk" FOREIGN KEY ("character_id") REFERENCES "public"."character"("id") ON DELETE no action ON UPDATE no action;
ALTER TABLE "custom_gpt_file_mapping" ADD CONSTRAINT "custom_gpt_file_mapping_file_id_file_table_id_fk" FOREIGN KEY ("file_id") REFERENCES "public"."file_table"("id") ON DELETE no action ON UPDATE no action;
ALTER TABLE "custom_gpt_file_mapping" ADD CONSTRAINT "custom_gpt_file_mapping_custom_gpt_id_custom_gpt_id_fk" FOREIGN KEY ("custom_gpt_id") REFERENCES "public"."custom_gpt"("id") ON DELETE no action ON UPDATE no action;
ALTER TABLE "shared_conversation_file_mapping" ADD CONSTRAINT "shared_school_conversation_file_mapping_fileId_file_table_id_fk" FOREIGN KEY ("fileId") REFERENCES "public"."file_table"("id") ON DELETE no action ON UPDATE no action;
ALTER TABLE "shared_conversation_file_mapping" ADD CONSTRAINT "shared_school_conversation_file_mapping_shared_school_conversation_id_shared_school_conversation_id_fk" FOREIGN KEY ("shared_school_conversation_id") REFERENCES "public"."shared_school_conversation"("id") ON DELETE no action ON UPDATE no action;

-- 0012_nebulous_justin_hammer.sql
ALTER TABLE "shared_school_conversation" ADD COLUMN IF NOT EXISTS "attached_links" text[] DEFAULT '{}'::text[] NOT NULL;
ALTER TABLE "shared_school_conversation" ADD COLUMN IF NOT EXISTS "picture_id" text;

-- 0013_narrow_the_executioner.sql
ALTER TABLE "shared_school_conversation" RENAME COLUMN "learning_context" TO "student_excercise";
ALTER TABLE "shared_school_conversation" RENAME COLUMN "specification" TO "additional_instructions";
ALTER TABLE "shared_school_conversation" ALTER COLUMN "school_type" DROP DEFAULT;
ALTER TABLE "shared_school_conversation" ALTER COLUMN "school_type" DROP NOT NULL;
ALTER TABLE "shared_school_conversation" ALTER COLUMN "grade_level" DROP DEFAULT;
ALTER TABLE "shared_school_conversation" ALTER COLUMN "grade_level" DROP NOT NULL;
ALTER TABLE "shared_school_conversation" ALTER COLUMN "subject" DROP DEFAULT;
ALTER TABLE "shared_school_conversation" ALTER COLUMN "subject" DROP NOT NULL;

-- 0014_bouncy_warbird.sql
CREATE TABLE IF NOT EXISTS "text_chunk" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"file_id" text NOT NULL,
	"embedding" vector(1024) NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"content" text NOT NULL,
	"leading_overlap" text,
	"trailing_overlap" text,
	"order_index" integer NOT NULL,
	"page_number" integer,
	"content_tsv" "tsvector" GENERATED ALWAYS AS (to_tsvector('german', content)) STORED NOT NULL
);
ALTER TABLE "text_chunk" ADD CONSTRAINT "text_chunk_file_id_file_table_id_fk" FOREIGN KEY ("file_id") REFERENCES "public"."file_table"("id") ON DELETE no action ON UPDATE no action;

-- 0015_fearless_morlocks.sql
ALTER TABLE "federal_state" ADD COLUMN IF NOT EXISTS "design_configuration" json;
ALTER TABLE "federal_state" ADD COLUMN IF NOT EXISTS "telli_name" text;

-- 0016_parallel_sir_ram.sql
ALTER TABLE "file_table" ADD COLUMN IF NOT EXISTS "metadata" json;
ALTER TABLE "llm_model" ADD COLUMN IF NOT EXISTS "supported_image_formats" json;

-- 0017_smart_ozymandias.sql
ALTER TABLE "character" ADD COLUMN IF NOT EXISTS "initial_message" text;

-- 0018_high_alex_wilder.sql
ALTER TABLE "character" ADD COLUMN IF NOT EXISTS "attached_links" text[] DEFAULT '{}'::text[] NOT NULL;
ALTER TABLE "custom_gpt" ADD COLUMN IF NOT EXISTS "attached_links" text[] DEFAULT '{}'::text[] NOT NULL;

-- 0019_dusty_exodus.sql
-- Migrate existing data to JSON format
UPDATE "federal_state"
SET "support_contact" = json_build_array("support_contact")
WHERE "support_contact" IS NOT NULL;

-- 0020_wakeful_pride.sql
ALTER TABLE "federal_state" RENAME COLUMN "support_contact" TO "support_contacts";
-- Manually set, because drizzle-kit didn't automatically include this
ALTER TABLE "federal_state" ALTER COLUMN "support_contacts" SET DATA TYPE json USING "support_contacts"::json;

-- 0021_yielding_giant_girl.sql
ALTER TABLE "llm_model" ADD COLUMN IF NOT EXISTS "additional_parameters" json DEFAULT '[]'::json NOT NULL;
ALTER TABLE "llm_model" ADD COLUMN IF NOT EXISTS "is_new" boolean DEFAULT false NOT NULL;
ALTER TABLE "llm_model" ADD COLUMN IF NOT EXISTS "is_deleted" boolean DEFAULT false NOT NULL;

-- 0022_special_maddog.sql
ALTER TABLE "llm_model" DROP COLUMN IF EXISTS "additional_parameters";

-- 0023_curved_weapon_omega.sql
DO $$ BEGIN
 CREATE TYPE "public"."voucher_status" AS ENUM('active', 'used', 'revoked');
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
CREATE TABLE IF NOT EXISTS "voucher" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"code" text NOT NULL,
	"increase_amount" integer NOT NULL,
	"duration_months" integer NOT NULL,
	"status" "voucher_status" DEFAULT 'active' NOT NULL,
	"valid_until" timestamp with time zone NOT NULL,
	"federal_state_id" text NOT NULL,
	"redeemed_by" uuid,
	"redeemed_at" timestamp with time zone,
	"created_by" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"create_reason" text DEFAULT '' NOT NULL,
	"updated_by" text,
	"updated_at" timestamp with time zone,
	"update_reason" text DEFAULT '' NOT NULL,
	CONSTRAINT "voucher_code_unique" UNIQUE("code")
);
ALTER TABLE "voucher" ADD CONSTRAINT "voucher_federal_state_id_federal_state_id_fk" FOREIGN KEY ("federal_state_id") REFERENCES "public"."federal_state"("id") ON DELETE no action ON UPDATE no action;
ALTER TABLE "voucher" ADD CONSTRAINT "voucher_redeemed_by_user_entity_id_fk" FOREIGN KEY ("redeemed_by") REFERENCES "public"."user_entity"("id") ON DELETE no action ON UPDATE no action;

-- 0024_ambiguous_invisible_woman.sql
ALTER TABLE "voucher" ALTER COLUMN "status" SET DATA TYPE text;
ALTER TABLE "voucher" ALTER COLUMN "status" SET DEFAULT 'created'::text;
DROP TYPE IF EXISTS "public"."voucher_status";
CREATE TYPE "public"."voucher_status" AS ENUM('created', 'redeemed', 'revoked');
ALTER TABLE "voucher" ALTER COLUMN "status" SET DEFAULT 'created'::"public"."voucher_status";
ALTER TABLE "voucher" ALTER COLUMN "status" SET DATA TYPE "public"."voucher_status" USING "status"::"public"."voucher_status";

-- 0025_remarkable_queen_noir.sql
ALTER TABLE "conversation_usage_tracking" ADD COLUMN IF NOT EXISTS "costs_in_cent" double precision DEFAULT 0 NOT NULL;
ALTER TABLE "shared_character_chat_usage_tracking" ADD COLUMN IF NOT EXISTS "costs_in_cent" double precision DEFAULT 0 NOT NULL;
ALTER TABLE "shared_school_conversation_usage_tracking" ADD COLUMN IF NOT EXISTS "costs_in_cent" double precision DEFAULT 0 NOT NULL;

-- 0026_fancy_umar.sql
CREATE TABLE IF NOT EXISTS "character_template_mappings" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"character_id" uuid NOT NULL,
	"federal_state_id" text NOT NULL
);
CREATE TABLE IF NOT EXISTS "custom_gpt_template_mappings" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"custom_gpt_id" uuid NOT NULL,
	"federal_state_id" text NOT NULL
);
ALTER TABLE "character" ADD COLUMN IF NOT EXISTS "is_deleted" boolean DEFAULT false NOT NULL;
ALTER TABLE "character" ADD COLUMN IF NOT EXISTS "original_character_id" uuid;
ALTER TABLE "custom_gpt" ADD COLUMN IF NOT EXISTS "is_deleted" boolean DEFAULT false NOT NULL;
ALTER TABLE "custom_gpt" ADD COLUMN IF NOT EXISTS "original_custom_gpt_id" uuid;
ALTER TABLE "character_template_mappings" ADD CONSTRAINT "character_template_mappings_character_id_character_id_fk" FOREIGN KEY ("character_id") REFERENCES "public"."character"("id") ON DELETE cascade ON UPDATE no action;
ALTER TABLE "character_template_mappings" ADD CONSTRAINT "character_template_mappings_federal_state_id_federal_state_id_fk" FOREIGN KEY ("federal_state_id") REFERENCES "public"."federal_state"("id") ON DELETE cascade ON UPDATE no action;
ALTER TABLE "custom_gpt_template_mappings" ADD CONSTRAINT "custom_gpt_template_mappings_custom_gpt_id_custom_gpt_id_fk" FOREIGN KEY ("custom_gpt_id") REFERENCES "public"."custom_gpt"("id") ON DELETE cascade ON UPDATE no action;
ALTER TABLE "custom_gpt_template_mappings" ADD CONSTRAINT "custom_gpt_template_mappings_federal_state_id_federal_state_id_fk" FOREIGN KEY ("federal_state_id") REFERENCES "public"."federal_state"("id") ON DELETE cascade ON UPDATE no action;

-- 0027_cultured_nehzno.sql
CREATE INDEX IF NOT EXISTS "conversation_message_file_mapping_conversationMessageId_index" ON "conversation_message_file_mapping" USING btree ("conversationMessageId");
CREATE INDEX IF NOT EXISTS "text_chunk_file_id_index" ON "text_chunk" USING btree ("file_id");
CREATE INDEX IF NOT EXISTS "voucher_federal_state_id_index" ON "voucher" USING btree ("federal_state_id");
CREATE INDEX IF NOT EXISTS "voucher_redeemed_by_index" ON "voucher" USING btree ("redeemed_by");
CREATE INDEX IF NOT EXISTS "character_user_id_index" ON "character" USING btree ("user_id");
CREATE INDEX IF NOT EXISTS "character_school_id_index" ON "character" USING btree ("school_id");
CREATE INDEX IF NOT EXISTS "character_template_mappings_character_id_index" ON "character_template_mappings" USING btree ("character_id");
CREATE INDEX IF NOT EXISTS "character_template_mappings_federal_state_id_index" ON "character_template_mappings" USING btree ("federal_state_id");
CREATE INDEX IF NOT EXISTS "conversation_message_conversation_id_index" ON "conversation_message" USING btree ("conversation_id");
CREATE INDEX IF NOT EXISTS "conversation_message_user_id_index" ON "conversation_message" USING btree ("user_id");
CREATE INDEX IF NOT EXISTS "conversation_user_id_index" ON "conversation" USING btree ("user_id");
CREATE INDEX IF NOT EXISTS "conversation_character_id_index" ON "conversation" USING btree ("character_id");
CREATE INDEX IF NOT EXISTS "conversation_custom_gpt_id_index" ON "conversation" USING btree ("custom_gpt_id");
CREATE INDEX IF NOT EXISTS "conversation_usage_tracking_conversation_id_index" ON "conversation_usage_tracking" USING btree ("conversation_id");
CREATE INDEX IF NOT EXISTS "conversation_usage_tracking_user_id_index" ON "conversation_usage_tracking" USING btree ("user_id");
CREATE INDEX IF NOT EXISTS "conversation_usage_tracking_created_at_index" ON "conversation_usage_tracking" USING btree ("created_at");
CREATE INDEX IF NOT EXISTS "custom_gpt_user_id_index" ON "custom_gpt" USING btree ("user_id");
CREATE INDEX IF NOT EXISTS "custom_gpt_school_id_index" ON "custom_gpt" USING btree ("school_id");
CREATE INDEX IF NOT EXISTS "custom_gpt_template_mappings_custom_gpt_id_index" ON "custom_gpt_template_mappings" USING btree ("custom_gpt_id");
CREATE INDEX IF NOT EXISTS "custom_gpt_template_mappings_federal_state_id_index" ON "custom_gpt_template_mappings" USING btree ("federal_state_id");
CREATE INDEX IF NOT EXISTS "school_federal_state_id_index" ON "school" USING btree ("federal_state_id");
CREATE INDEX IF NOT EXISTS "shared_character_chat_usage_tracking_character_id_index" ON "shared_character_chat_usage_tracking" USING btree ("character_id");
CREATE INDEX IF NOT EXISTS "shared_character_chat_usage_tracking_user_id_index" ON "shared_character_chat_usage_tracking" USING btree ("user_id");
CREATE INDEX IF NOT EXISTS "shared_character_chat_usage_tracking_created_at_index" ON "shared_character_chat_usage_tracking" USING btree ("created_at");
CREATE INDEX IF NOT EXISTS "shared_school_conversation_user_id_index" ON "shared_school_conversation" USING btree ("user_id");
CREATE INDEX IF NOT EXISTS "shared_school_conversation_usage_tracking_shared_school_conversation_id_index" ON "shared_school_conversation_usage_tracking" USING btree ("shared_school_conversation_id");
CREATE INDEX IF NOT EXISTS "shared_school_conversation_usage_tracking_user_id_index" ON "shared_school_conversation_usage_tracking" USING btree ("user_id");
CREATE INDEX IF NOT EXISTS "shared_school_conversation_usage_tracking_created_at_index" ON "shared_school_conversation_usage_tracking" USING btree ("created_at");

-- 0028_abandoned_pestilence.sql
ALTER TABLE "text_chunk" DROP CONSTRAINT IF EXISTS "text_chunk_file_id_file_table_id_fk";
ALTER TABLE "text_chunk" ADD CONSTRAINT "text_chunk_file_id_file_table_id_fk" FOREIGN KEY ("file_id") REFERENCES "public"."file_table"("id") ON DELETE cascade ON UPDATE no action;

-- 0029_omniscient_fat_cobra.sql
ALTER TABLE "conversation_message" ALTER COLUMN "role" SET DATA TYPE text;
DROP TYPE IF EXISTS "public"."conversation_role";
CREATE TYPE "public"."conversation_role" AS ENUM('user', 'assistant', 'system', 'data');
ALTER TABLE "conversation_message" ALTER COLUMN "role" SET DATA TYPE "public"."conversation_role" USING "role"::"public"."conversation_role";

-- 0030_round_titanium_man.sql
DELETE FROM "character_template_mappings";
DELETE FROM "custom_gpt_template_mappings";
DROP INDEX IF EXISTS "character_template_mappings_character_id_index";
DROP INDEX IF EXISTS "character_template_mappings_federal_state_id_index";
DROP INDEX IF EXISTS "custom_gpt_template_mappings_custom_gpt_id_index";
DROP INDEX IF EXISTS "custom_gpt_template_mappings_federal_state_id_index";
ALTER TABLE "character_template_mappings" DROP COLUMN IF EXISTS "id";
ALTER TABLE "custom_gpt_template_mappings" DROP COLUMN IF EXISTS "id";
ALTER TABLE "character_template_mappings" ADD CONSTRAINT "character_template_mappings_character_id_federal_state_id_pk" PRIMARY KEY("character_id","federal_state_id");
ALTER TABLE "custom_gpt_template_mappings" ADD CONSTRAINT "custom_gpt_template_mappings_custom_gpt_id_federal_state_id_pk" PRIMARY KEY("custom_gpt_id","federal_state_id");

-- Insert select, so all global templates are assigned to all federal states
INSERT INTO "character_template_mappings" ("character_id", "federal_state_id")
SELECT c.id AS character_id, f.id AS federal_state_id
FROM "character" c, "federal_state" f
WHERE c.access_level = 'global';
INSERT INTO "custom_gpt_template_mappings" ("custom_gpt_id", "federal_state_id")
SELECT cgpt.id AS custom_gpt_id, f.id AS federal_state_id
FROM "custom_gpt" cgpt, "federal_state" f
WHERE cgpt.access_level = 'global';

-- 0031_smart_timeslip.sql
CREATE INDEX IF NOT EXISTS "conversation_user_id_created_at_index" ON "conversation" USING btree ("user_id","created_at" DESC NULLS LAST) WHERE "conversation"."deleted_at" is null;

-- 0032_tranquil_blackheart.sql
ALTER TABLE "federal_state" ADD COLUMN IF NOT EXISTS "feature_toggles" json;
-- migrate data from old columns to new json column
UPDATE "federal_state" SET "feature_toggles" = json_build_object(
'isStudentAccessEnabled', "student_access",
'isCharacterEnabled', "enable_characters",
'isSharedChatEnabled', "enable_shared_chats",
'isCustomGptEnabled', "enable_custom_gpts",
'isShareTemplateWithSchoolEnabled', true
);
ALTER TABLE "federal_state" ALTER COLUMN "feature_toggles" SET NOT NULL;
ALTER TABLE "federal_state" DROP COLUMN IF EXISTS "student_access";
ALTER TABLE "federal_state" DROP COLUMN IF EXISTS "enable_characters";
ALTER TABLE "federal_state" DROP COLUMN IF EXISTS "enable_shared_chats";
ALTER TABLE "federal_state" DROP COLUMN IF EXISTS "enable_custom_gpts";

-- 0033_complex_agent_zero.sql
DO $$ BEGIN
 CREATE TYPE "public"."conversation_type" AS ENUM('chat', 'image-generation');
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
ALTER TABLE "conversation_message" ADD COLUMN IF NOT EXISTS "parameters" json;
ALTER TABLE "conversation" ADD COLUMN IF NOT EXISTS "type" "conversation_type" DEFAULT 'chat' NOT NULL;

-- 0034_bumpy_puff_adder.sql
ALTER TABLE "character_file_mapping" DROP CONSTRAINT IF EXISTS "character_file_mapping_character_id_character_id_fk";
ALTER TABLE "custom_gpt_file_mapping" DROP CONSTRAINT IF EXISTS "custom_gpt_file_mapping_custom_gpt_id_custom_gpt_id_fk";
ALTER TABLE "shared_conversation_file_mapping" DROP CONSTRAINT IF EXISTS "shared_school_conversation_file_mapping_shared_school_conversat";
ALTER TABLE "character_file_mapping" ADD CONSTRAINT "character_file_mapping_character_id_character_id_fk" FOREIGN KEY ("character_id") REFERENCES "public"."character"("id") ON DELETE cascade ON UPDATE no action;
ALTER TABLE "custom_gpt_file_mapping" ADD CONSTRAINT "custom_gpt_file_mapping_custom_gpt_id_custom_gpt_id_fk" FOREIGN KEY ("custom_gpt_id") REFERENCES "public"."custom_gpt"("id") ON DELETE cascade ON UPDATE no action;
ALTER TABLE "shared_conversation_file_mapping" ADD CONSTRAINT "shared_school_conversation_id_shared_school_conversation_id_fk" FOREIGN KEY ("shared_school_conversation_id") REFERENCES "public"."shared_school_conversation"("id") ON DELETE cascade ON UPDATE no action;

-- 0035_awesome_mulholland_black.sql
ALTER TABLE "federal_state" ADD COLUMN IF NOT EXISTS "api_key_id" uuid;

-- 0036_fair_fenris.sql
ALTER TABLE "character" DROP CONSTRAINT IF EXISTS "character_invite_code_unique";
ALTER TABLE "character" DROP COLUMN IF EXISTS "intelligence_points_limit";
ALTER TABLE "character" DROP COLUMN IF EXISTS "max_usage_time_limit";
ALTER TABLE "character" DROP COLUMN IF EXISTS "invite_code";
ALTER TABLE "character" DROP COLUMN IF EXISTS "started_at";

-- 0037_long_bloodstrike.sql
ALTER TABLE "conversation_message_file_mapping" DROP CONSTRAINT IF EXISTS "conversation_message_file_mapping_conversationMessageId_convers";
ALTER TABLE "conversation_message_file_mapping" DROP CONSTRAINT IF EXISTS "conversation_message_file_mapping_conversationId_conversation_i";
ALTER TABLE "conversation_message_file_mapping" ADD CONSTRAINT "conversation_message_file_mapping_conversationMessageId_fk" FOREIGN KEY ("conversationMessageId") REFERENCES "public"."conversation_message"("id") ON DELETE cascade ON UPDATE no action;
ALTER TABLE "conversation_message_file_mapping" ADD CONSTRAINT "conversation_message_file_mapping_conversationId_fk" FOREIGN KEY ("conversationId") REFERENCES "public"."conversation"("id") ON DELETE cascade ON UPDATE no action;

-- 0038_wonderful_naoko.sql
ALTER TABLE "shared_conversation_file_mapping" DROP CONSTRAINT IF EXISTS "shared_conversation_file_mapping_shared_school_conversation_id_";
ALTER TABLE "federal_state_llm_model_mapping" DROP CONSTRAINT IF EXISTS "federal_state_llm_model_mapping_federal_state_id_llm_model_id_u";
ALTER TABLE "character_template_mappings" DROP CONSTRAINT IF EXISTS "character_template_mappings_federal_state_id_federal_state_id_f";
ALTER TABLE "custom_gpt_template_mappings" DROP CONSTRAINT IF EXISTS "custom_gpt_template_mappings_federal_state_id_federal_state_id_";
ALTER TABLE "federal_state_llm_model_mapping" DROP CONSTRAINT IF EXISTS "federal_state_llm_model_mapping_federal_state_id_federal_state_";
ALTER TABLE "shared_school_conversation_usage_tracking" DROP CONSTRAINT IF EXISTS "shared_school_conversation_usage_tracking_model_id_llm_model_id";
DROP INDEX IF EXISTS "shared_school_conversation_usage_tracking_shared_school_convers";
ALTER TABLE "character_template_mappings" ADD CONSTRAINT "character_template_mappings_federal_state_id_fk" FOREIGN KEY ("federal_state_id") REFERENCES "public"."federal_state"("id") ON DELETE cascade ON UPDATE no action;
ALTER TABLE "custom_gpt_template_mappings" ADD CONSTRAINT "character_template_mappings_federal_state_id_fk" FOREIGN KEY ("federal_state_id") REFERENCES "public"."federal_state"("id") ON DELETE cascade ON UPDATE no action;
ALTER TABLE "federal_state_llm_model_mapping" ADD CONSTRAINT "federal_state_llm_model_mapping_federal_state_id_fk" FOREIGN KEY ("federal_state_id") REFERENCES "public"."federal_state"("id") ON DELETE no action ON UPDATE no action;
ALTER TABLE "shared_school_conversation_usage_tracking" ADD CONSTRAINT "shared_school_conversation_usage_tracking_model_id_fk" FOREIGN KEY ("model_id") REFERENCES "public"."llm_model"("id") ON DELETE no action ON UPDATE no action;
CREATE INDEX IF NOT EXISTS "shared_school_conversation_usage_tracking_conversation_id_index" ON "shared_school_conversation_usage_tracking" USING btree ("shared_school_conversation_id");
ALTER TABLE "shared_conversation_file_mapping" ADD CONSTRAINT "shared_conversation_file_mapping_conversation_id_fileId_unique" UNIQUE("shared_school_conversation_id","fileId");
ALTER TABLE "federal_state_llm_model_mapping" ADD CONSTRAINT "federal_state_llm_model_mapping_federal_state_llm_model_unique" UNIQUE("federal_state_id","llm_model_id");

-- 0039_loud_carlie_cooper.sql
ALTER TYPE "public"."character_access_level" RENAME TO "access_level";

-- 0040_flowery_blob.sql
ALTER TABLE "shared_character_conversation" RENAME COLUMN "intelligence_points_limit" TO "telli_points_limit";
ALTER TABLE "shared_school_conversation" RENAME COLUMN "intelligence_points_limit" TO "telli_points_limit";

-- 0041_late_the_liberteens.sql
ALTER TABLE "llm_model" RENAME COLUMN "price_metada" TO "price_metadata";
ALTER TABLE "shared_school_conversation" RENAME COLUMN "student_excercise" TO "student_exercise";

-- 0042_salty_mandroid.sql
-- Set user_id on the conversation_message according to the value from the conversation
UPDATE conversation_message AS cm
SET user_id = c.user_id
FROM conversation AS c
WHERE c.id = cm.conversation_id
  AND cm.user_id IS NULL;

-- Fill model_name for messages where it's NULL using a model_name from another message
-- of the same conversation_id; if none exists in that conversation, fall back to 'imagen-4.0-generate-001'.
UPDATE conversation_message AS cm
SET model_name = COALESCE(
    (
        SELECT cm2.model_name
        FROM conversation_message AS cm2
        WHERE cm2.conversation_id = cm.conversation_id
          AND cm2.model_name IS NOT NULL
        LIMIT 1
    ),
    'imagen-4.0-generate-001'
)
WHERE cm.model_name IS NULL;

ALTER TABLE "conversation_message" ALTER COLUMN "model_name" SET NOT NULL;
ALTER TABLE "conversation_message" ALTER COLUMN "user_id" SET NOT NULL;

-- 0043_yielding_namorita.sql
ALTER TABLE "conversation_message" ADD COLUMN IF NOT EXISTS "websearch_sources" json DEFAULT '[]'::json NOT NULL;

-- 0044_third_maximus.sql
ALTER TABLE "shared_conversation_file_mapping" RENAME TO "learning_scenario_file_mapping";
ALTER TABLE "shared_school_conversation" RENAME TO "learning_scenario";
ALTER TABLE "shared_school_conversation_usage_tracking" RENAME TO "shared_learning_scenario_usage_tracking";
ALTER TABLE "learning_scenario_file_mapping" RENAME COLUMN "fileId" TO "file_id";
ALTER TABLE "learning_scenario_file_mapping" RENAME COLUMN "shared_school_conversation_id" TO "learning_scenario_id";
ALTER TABLE "shared_learning_scenario_usage_tracking" RENAME COLUMN "shared_school_conversation_id" TO "learning_scenario_id";
ALTER TABLE "learning_scenario_file_mapping" DROP CONSTRAINT IF EXISTS "shared_conversation_file_mapping_conversation_id_fileId_unique";
ALTER TABLE "learning_scenario" DROP CONSTRAINT IF EXISTS "shared_school_conversation_invite_code_unique";
ALTER TABLE "learning_scenario_file_mapping" DROP CONSTRAINT IF EXISTS "shared_school_conversation_file_mapping_fileId_file_table_id_fk";
ALTER TABLE "learning_scenario_file_mapping" DROP CONSTRAINT IF EXISTS "shared_school_conversation_id_shared_school_conversation_id_fk";
ALTER TABLE "learning_scenario" DROP CONSTRAINT IF EXISTS "shared_school_conversation_model_id_llm_model_id_fk";
ALTER TABLE "learning_scenario" DROP CONSTRAINT IF EXISTS "shared_school_conversation_user_id_user_entity_id_fk";
ALTER TABLE "shared_learning_scenario_usage_tracking" DROP CONSTRAINT IF EXISTS "shared_school_conversation_usage_tracking_model_id_fk";
DROP INDEX IF EXISTS "shared_school_conversation_user_id_index";
DROP INDEX IF EXISTS "shared_school_conversation_usage_tracking_conversation_id_index";
DROP INDEX IF EXISTS "shared_school_conversation_usage_tracking_user_id_index";
DROP INDEX IF EXISTS "shared_school_conversation_usage_tracking_created_at_index";
ALTER TABLE "learning_scenario_file_mapping" ADD CONSTRAINT "learning_scenario_file_mapping_file_id_file_table_id_fk" FOREIGN KEY ("file_id") REFERENCES "public"."file_table"("id") ON DELETE no action ON UPDATE no action;
ALTER TABLE "learning_scenario_file_mapping" ADD CONSTRAINT "learning_scenario_file_mapping_learning_scenario_id_fk" FOREIGN KEY ("learning_scenario_id") REFERENCES "public"."learning_scenario"("id") ON DELETE cascade ON UPDATE no action;
ALTER TABLE "learning_scenario" ADD CONSTRAINT "learning_scenario_model_id_llm_model_id_fk" FOREIGN KEY ("model_id") REFERENCES "public"."llm_model"("id") ON DELETE no action ON UPDATE no action;
ALTER TABLE "learning_scenario" ADD CONSTRAINT "learning_scenario_user_id_user_entity_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user_entity"("id") ON DELETE no action ON UPDATE no action;
ALTER TABLE "shared_learning_scenario_usage_tracking" ADD CONSTRAINT "shared_learning_scenario_usage_tracking_model_id_fk" FOREIGN KEY ("model_id") REFERENCES "public"."llm_model"("id") ON DELETE no action ON UPDATE no action;
CREATE INDEX IF NOT EXISTS "learning_scenario_user_id_index" ON "learning_scenario" USING btree ("user_id");
CREATE INDEX IF NOT EXISTS "shared_learning_scenario_usage_tracking_conversation_id_index" ON "shared_learning_scenario_usage_tracking" USING btree ("learning_scenario_id");
CREATE INDEX IF NOT EXISTS "shared_learning_scenario_usage_tracking_user_id_index" ON "shared_learning_scenario_usage_tracking" USING btree ("user_id");
CREATE INDEX IF NOT EXISTS "shared_learning_scenario_usage_tracking_created_at_index" ON "shared_learning_scenario_usage_tracking" USING btree ("created_at");
ALTER TABLE "learning_scenario_file_mapping" ADD CONSTRAINT "learning_scenario_file_mapping_learningScenarioId_fileId_unique" UNIQUE("learning_scenario_id","file_id");
ALTER TABLE "learning_scenario" ADD CONSTRAINT "learning_scenario_invite_code_unique" UNIQUE("invite_code");

-- 0045_romantic_lord_hawal.sql
CREATE TABLE IF NOT EXISTS "shared_learning_scenario" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"learning_scenario_id" uuid NOT NULL,
	"user_id" uuid NOT NULL,
	"telli_points_limit" integer,
	"max_usage_time_limit" integer,
	"invite_code" text,
	"started_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "shared_learning_scenario_invite_code_unique" UNIQUE("invite_code"),
	CONSTRAINT "shared_learning_scenario_learning_scenario_id_user_id_unique" UNIQUE("learning_scenario_id","user_id")
);

-- Migrate data from "learning_scenario" to "shared_learning_scenario"
INSERT INTO "shared_learning_scenario" (
    "learning_scenario_id",
    "user_id",
    "telli_points_limit",
    "max_usage_time_limit",
    "invite_code",
    "started_at"
)
SELECT
    ls."id" AS "learning_scenario_id",
    ls."user_id",
    ls."telli_points_limit",
    ls."max_usage_time_limit",
    ls."invite_code",
    ls."started_at"
FROM "learning_scenario" ls
WHERE ls."started_at" IS NOT NULL;

ALTER TABLE "learning_scenario" DROP CONSTRAINT IF EXISTS "learning_scenario_invite_code_unique";
ALTER TABLE "learning_scenario" ADD COLUMN IF NOT EXISTS "access_level" "access_level" DEFAULT 'private' NOT NULL;
ALTER TABLE "learning_scenario" ADD COLUMN IF NOT EXISTS "school_id" text;
ALTER TABLE "learning_scenario" ADD COLUMN IF NOT EXISTS "original_learning_scenario_id" uuid;
ALTER TABLE "shared_learning_scenario" ADD CONSTRAINT "shared_learning_scenario_user_id_user_entity_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user_entity"("id") ON DELETE no action ON UPDATE no action;
ALTER TABLE "learning_scenario" ADD CONSTRAINT "learning_scenario_school_id_school_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."school"("id") ON DELETE no action ON UPDATE no action;
ALTER TABLE "learning_scenario" DROP COLUMN IF EXISTS "telli_points_limit";
ALTER TABLE "learning_scenario" DROP COLUMN IF EXISTS "max_usage_time_limit";
ALTER TABLE "learning_scenario" DROP COLUMN IF EXISTS "invite_code";
ALTER TABLE "learning_scenario" DROP COLUMN IF EXISTS "started_at";

-- 0046_fat_reaper.sql
CREATE TABLE IF NOT EXISTS "learning_scenario_template_mappings" (
	"learning_scenario_id" uuid NOT NULL,
	"federal_state_id" text NOT NULL,
	CONSTRAINT "learning_scenario_template_mappings_pk" PRIMARY KEY("learning_scenario_id","federal_state_id")
);
ALTER TABLE "learning_scenario_template_mappings" ADD CONSTRAINT "learning_scenario_template_mappings_learning_scenario_id_fk" FOREIGN KEY ("learning_scenario_id") REFERENCES "public"."learning_scenario"("id") ON DELETE cascade ON UPDATE no action;
ALTER TABLE "learning_scenario_template_mappings" ADD CONSTRAINT "learning_scenario_template_mappings_federal_state_id_fk" FOREIGN KEY ("federal_state_id") REFERENCES "public"."federal_state"("id") ON DELETE cascade ON UPDATE no action;

-- Drop invalid columns before adding FK constraint
DELETE FROM "shared_learning_scenario"
WHERE "learning_scenario_id" NOT IN (SELECT "id" FROM "public"."learning_scenario");
ALTER TABLE "shared_learning_scenario" ADD CONSTRAINT "shared_learning_scenario_learning_scenario_id_fk" FOREIGN KEY ("learning_scenario_id") REFERENCES "public"."learning_scenario"("id") ON DELETE cascade ON UPDATE no action;

-- Set the schoolId for all learning scenarios; required for school-internal sharing
WITH first_school_per_user AS (
    SELECT DISTINCT ON (usm.user_id)
        usm.user_id,
        usm.school_id
    FROM user_school_mapping usm
    ORDER BY usm.user_id, usm.created_at
)
UPDATE learning_scenario ls
SET school_id = fs.school_id
FROM first_school_per_user fs
WHERE ls.school_id IS NULL
  AND fs.user_id = ls.user_id;

-- 0047_little_enchantress.sql
ALTER TABLE "learning_scenario" ADD COLUMN IF NOT EXISTS "is_deleted" boolean DEFAULT false NOT NULL;

-- 0048_sharp_rattler.sql
ALTER TABLE "character" ADD COLUMN IF NOT EXISTS "has_link_access" boolean DEFAULT false NOT NULL;
ALTER TABLE "custom_gpt" ADD COLUMN IF NOT EXISTS "has_link_access" boolean DEFAULT false NOT NULL;
ALTER TABLE "learning_scenario" ADD COLUMN IF NOT EXISTS "has_link_access" boolean DEFAULT false NOT NULL;

-- 0049_smart_drax.sql
ALTER TABLE "shared_learning_scenario" ALTER COLUMN "started_at" DROP NOT NULL;
ALTER TABLE "shared_character_conversation" DROP COLUMN IF EXISTS "created_at";

-- 0050_parallel_ken_ellis.sql
ALTER TABLE "file_table" ADD COLUMN IF NOT EXISTS "user_id" uuid;
ALTER TABLE "file_table" ADD CONSTRAINT "file_table_user_id_user_entity_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user_entity"("id") ON DELETE no action ON UPDATE no action;
CREATE INDEX IF NOT EXISTS "file_table_user_id_index" ON "file_table" USING btree ("user_id");

-- 0051_foamy_the_call.sql
DROP INDEX IF EXISTS "text_chunk_content_tsv_idx";
ALTER TABLE "text_chunk" DROP COLUMN IF EXISTS "content_tsv";

-- 0052_superb_gressill.sql
DO $$ BEGIN
 CREATE TYPE "public"."chunk_source_type" AS ENUM('file', 'webpage');
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
ALTER TABLE "text_chunk" ALTER COLUMN "file_id" DROP NOT NULL;
ALTER TABLE "text_chunk" ADD COLUMN IF NOT EXISTS "source_type" "chunk_source_type" DEFAULT 'file' NOT NULL;
ALTER TABLE "text_chunk" ADD COLUMN IF NOT EXISTS "source_url" text;
CREATE INDEX IF NOT EXISTS "text_chunk_source_url_index" ON "text_chunk" USING btree ("source_url");
ALTER TABLE "text_chunk" DROP COLUMN IF EXISTS "leading_overlap";
ALTER TABLE "text_chunk" DROP COLUMN IF EXISTS "trailing_overlap";

-- 0053_familiar_mandroid.sql
ALTER TABLE "text_chunk" RENAME TO "chunk";
ALTER TABLE "chunk" DROP CONSTRAINT IF EXISTS "text_chunk_file_id_file_table_id_fk";
DROP INDEX IF EXISTS "text_chunk_file_id_index";
DROP INDEX IF EXISTS "text_chunk_embedding_idx";
DROP INDEX IF EXISTS "text_chunk_source_url_index";
ALTER TABLE "chunk" ADD CONSTRAINT "chunk_file_id_file_table_id_fk" FOREIGN KEY ("file_id") REFERENCES "public"."file_table"("id") ON DELETE cascade ON UPDATE no action;
CREATE INDEX IF NOT EXISTS "chunk_file_id_index" ON "chunk" USING btree ("file_id");
CREATE INDEX IF NOT EXISTS "chunk_embedding_idx" ON "chunk" USING hnsw ("embedding" vector_cosine_ops);
ALTER TABLE "chunk" DROP COLUMN IF EXISTS "page_number";
ALTER TABLE "conversation_message" DROP COLUMN IF EXISTS "websearch_sources";
ALTER TABLE "chunk" ADD CONSTRAINT "chunk_source_url_order_index_unique" UNIQUE("source_url","order_index");
