"""add_multi_source_user_preferences

Revision ID: 9ba571487f62
Revises: a7618f996278
Create Date: 2025-05-26 17:31:15.312538

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision = '9ba571487f62'
down_revision = 'a7618f996278'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # User data source preferences table
    op.create_table('user_data_source_preferences',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('user_id', sa.UUID(), nullable=False),
        sa.Column('activity_source', sa.String(length=50), nullable=True),
        sa.Column('sleep_source', sa.String(length=50), nullable=True),
        sa.Column('nutrition_source', sa.String(length=50), nullable=True),
        sa.Column('body_composition_source', sa.String(length=50), nullable=True),
        sa.Column('priority_rules', sa.JSON(), nullable=True),
        sa.Column('conflict_resolution', sa.JSON(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_user_data_source_preferences_user_id'), 'user_data_source_preferences', ['user_id'], unique=True)

    # Unified health metrics table for multi-source data
    op.create_table('health_metrics_unified',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('user_id', sa.UUID(), nullable=False),
        sa.Column('metric_type', sa.String(length=50), nullable=False),
        sa.Column('category', sa.String(length=30), nullable=False),  # activity, sleep, nutrition, body_composition
        sa.Column('value', sa.Numeric(precision=10, scale=3), nullable=False),
        sa.Column('unit', sa.String(length=20), nullable=False),
        sa.Column('timestamp', sa.DateTime(), nullable=False),
        sa.Column('data_source', sa.String(length=50), nullable=False),
        sa.Column('quality_score', sa.Numeric(precision=3, scale=2), nullable=True),
        sa.Column('is_primary', sa.Boolean(), nullable=False, default=False),
        sa.Column('source_specific_data', sa.JSON(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_health_metrics_unified_user_id'), 'health_metrics_unified', ['user_id'], unique=False)
    op.create_index(op.f('ix_health_metrics_unified_timestamp'), 'health_metrics_unified', ['timestamp'], unique=False)
    op.create_index(op.f('ix_health_metrics_unified_metric_type'), 'health_metrics_unified', ['metric_type'], unique=False)
    op.create_index(op.f('ix_health_metrics_unified_category'), 'health_metrics_unified', ['category'], unique=False)
    op.create_index('ix_health_metrics_unified_user_category_timestamp', 'health_metrics_unified', ['user_id', 'category', 'timestamp'], unique=False)

    # File processing jobs table for Apple Health and CSV imports
    op.create_table('file_processing_jobs',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('user_id', sa.UUID(), nullable=False),
        sa.Column('file_type', sa.String(length=20), nullable=False),  # apple_health, csv
        sa.Column('filename', sa.String(length=255), nullable=False),
        sa.Column('file_path', sa.String(length=500), nullable=False),
        sa.Column('status', sa.String(length=20), nullable=False),  # pending, processing, completed, failed
        sa.Column('progress_percentage', sa.Integer(), nullable=False, default=0),
        sa.Column('total_records', sa.Integer(), nullable=True),
        sa.Column('processed_records', sa.Integer(), nullable=False, default=0),
        sa.Column('error_message', sa.Text(), nullable=True),
        sa.Column('processing_metadata', sa.JSON(), nullable=True),
        sa.Column('started_at', sa.DateTime(), nullable=True),
        sa.Column('completed_at', sa.DateTime(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_file_processing_jobs_user_id'), 'file_processing_jobs', ['user_id'], unique=False)
    op.create_index(op.f('ix_file_processing_jobs_status'), 'file_processing_jobs', ['status'], unique=False)

    # Data source availability and capabilities
    op.create_table('data_source_capabilities',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('source_name', sa.String(length=50), nullable=False),
        sa.Column('display_name', sa.String(length=100), nullable=False),
        sa.Column('supports_activity', sa.Boolean(), nullable=False, default=False),
        sa.Column('supports_sleep', sa.Boolean(), nullable=False, default=False),
        sa.Column('supports_nutrition', sa.Boolean(), nullable=False, default=False),
        sa.Column('supports_body_composition', sa.Boolean(), nullable=False, default=False),
        sa.Column('integration_type', sa.String(length=20), nullable=False),  # oauth2, file_upload
        sa.Column('oauth_config', sa.JSON(), nullable=True),
        sa.Column('api_endpoints', sa.JSON(), nullable=True),
        sa.Column('rate_limits', sa.JSON(), nullable=True),
        sa.Column('is_active', sa.Boolean(), nullable=False, default=True),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_data_source_capabilities_source_name'), 'data_source_capabilities', ['source_name'], unique=True)

    # Add data_source column to existing health_metrics table for backward compatibility
    op.add_column('health_metrics', sa.Column('data_source', sa.String(length=50), nullable=True, default='manual'))
    op.add_column('health_metrics', sa.Column('quality_score', sa.Numeric(precision=3, scale=2), nullable=True))

    # Add sync_frequency and preferences to data_source_connections
    op.add_column('data_source_connections', sa.Column('sync_frequency', sa.String(length=20), nullable=False, default='daily'))
    op.add_column('data_source_connections', sa.Column('sync_preferences', sa.JSON(), nullable=True))
    op.add_column('data_source_connections', sa.Column('is_active', sa.Boolean(), nullable=False, default=True))


def downgrade() -> None:
    # Remove added columns from existing tables
    op.drop_column('data_source_connections', 'is_active')
    op.drop_column('data_source_connections', 'sync_preferences')
    op.drop_column('data_source_connections', 'sync_frequency')
    op.drop_column('health_metrics', 'quality_score')
    op.drop_column('health_metrics', 'data_source')
    
    # Drop new tables
    op.drop_index(op.f('ix_data_source_capabilities_source_name'), table_name='data_source_capabilities')
    op.drop_table('data_source_capabilities')
    
    op.drop_index(op.f('ix_file_processing_jobs_status'), table_name='file_processing_jobs')
    op.drop_index(op.f('ix_file_processing_jobs_user_id'), table_name='file_processing_jobs')
    op.drop_table('file_processing_jobs')
    
    op.drop_index('ix_health_metrics_unified_user_category_timestamp', table_name='health_metrics_unified')
    op.drop_index(op.f('ix_health_metrics_unified_category'), table_name='health_metrics_unified')
    op.drop_index(op.f('ix_health_metrics_unified_metric_type'), table_name='health_metrics_unified')
    op.drop_index(op.f('ix_health_metrics_unified_timestamp'), table_name='health_metrics_unified')
    op.drop_index(op.f('ix_health_metrics_unified_user_id'), table_name='health_metrics_unified')
    op.drop_table('health_metrics_unified')
    
    op.drop_index(op.f('ix_user_data_source_preferences_user_id'), table_name='user_data_source_preferences')
    op.drop_table('user_data_source_preferences') 