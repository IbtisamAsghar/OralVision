-- SQL Schema Setup for OralVision Supabase tables

-- 1. Create the symptom assessments table
CREATE TABLE IF NOT EXISTS public.symptom_assessments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    symptoms_json JSONB NOT NULL,
    disease_class VARCHAR(255) NOT NULL,
    confidence_score NUMERIC(5, 4) NOT NULL,
    severity VARCHAR(50) NOT NULL,
    ai_report_text TEXT NOT NULL,
    pdf_url TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Index for fast queries by patient
CREATE INDEX IF NOT EXISTS idx_assessments_patient_id ON public.symptom_assessments(patient_id);

-- Enable RLS (Row Level Security)
ALTER TABLE public.symptom_assessments ENABLE ROW LEVEL SECURITY;

-- Setup RLS Policies
CREATE POLICY "Patients can view their own assessments"
    ON public.symptom_assessments FOR SELECT
    TO authenticated
    USING (auth.uid() = patient_id);

CREATE POLICY "Patients can insert their own assessments"
    ON public.symptom_assessments FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = patient_id);

-- 2. Future-Proofing: Chat sessions & messages (contextual chatbot per diagnosis)
CREATE TABLE IF NOT EXISTS public.chat_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    assessment_id UUID REFERENCES public.symptom_assessments(id) ON DELETE SET NULL,
    title VARCHAR(255) DEFAULT 'New Chat Session',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_chat_sessions_patient ON public.chat_sessions(patient_id);

ALTER TABLE public.chat_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Patients can manage their own sessions"
    ON public.chat_sessions FOR ALL
    TO authenticated
    USING (auth.uid() = patient_id);

CREATE TABLE IF NOT EXISTS public.chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES public.chat_sessions(id) ON DELETE CASCADE,
    sender VARCHAR(50) NOT NULL CHECK (sender IN ('user', 'assistant', 'system')),
    message_text TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_chat_messages_session ON public.chat_messages(session_id);

ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Patients can view messages in their sessions"
    ON public.chat_messages FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.chat_sessions
            WHERE chat_sessions.id = chat_messages.session_id
            AND chat_sessions.patient_id = auth.uid()
        )
    );

CREATE POLICY "Patients can send messages in their sessions"
    ON public.chat_messages FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.chat_sessions
            WHERE chat_sessions.id = chat_messages.session_id
            AND chat_sessions.patient_id = auth.uid()
        )
    );
