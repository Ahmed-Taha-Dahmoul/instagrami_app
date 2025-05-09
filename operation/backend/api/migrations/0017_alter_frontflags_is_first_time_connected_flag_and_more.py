# Generated by Django 5.1.5 on 2025-03-08 16:27

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('api', '0016_rename_front_flags_frontflags'),
    ]

    operations = [
        migrations.AlterField(
            model_name='frontflags',
            name='is_first_time_connected_flag',
            field=models.BooleanField(blank=True, default=True),
        ),
        migrations.AlterField(
            model_name='instagramuser_data',
            name='instagram_follower_count',
            field=models.PositiveIntegerField(blank=True, default=0),
        ),
        migrations.AlterField(
            model_name='instagramuser_data',
            name='instagram_following_count',
            field=models.PositiveIntegerField(blank=True, default=0),
        ),
        migrations.AlterField(
            model_name='instagramuser_data',
            name='instagram_total_posts',
            field=models.PositiveIntegerField(blank=True, default=0),
        ),
    ]
