create sequence video_cutter_id_sequence start with 1 increment by 1

CREATE TABLE public.video_cutter (
	id int8 NOT NULL,
	video_cutter_creation_date_time timestamp(6) NULL,
	video_cutter_last_update_date_time timestamp(6) NULL,
	video_cutter_size_in_bytes int8 NULL,
	video_cutter_user_id uuid NULL,
	video_cutter_file_id varchar(255) NULL,
	video_cutter_format varchar(255) NULL,
	video_cutter_name varchar(255) NULL,
	video_cutter_processing_status varchar(255) NULL,
	video_cutter_url varchar(255) NULL,
	video_cutter_user_email varchar(255) NULL,
	CONSTRAINT video_cutter_pkey PRIMARY KEY (id),
	CONSTRAINT video_cutter_video_cutter_file_id_key UNIQUE (video_cutter_file_id),
	CONSTRAINT video_cutter_video_cutter_format_check CHECK (((video_cutter_format)::text = 'MP4'::text)),
	CONSTRAINT video_cutter_video_cutter_processing_status_check CHECK (((video_cutter_processing_status)::text = ANY ((ARRAY['UPLOADING'::character varying, 'AWAITING_PROCESSING'::character varying, 'PROCESSING'::character varying, 'FINISHED'::character varying, 'ERROR'::character varying])::text[])))
);
