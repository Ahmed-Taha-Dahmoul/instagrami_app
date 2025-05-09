# Generated by Django 5.1.5 on 2025-04-17 08:50

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('api', '0022_rename_who_remove_following_instagramuser_data_who_removed_follower_and_more'),
    ]

    operations = [
        migrations.AddField(
            model_name='instagramuser_data',
            name='old_instagram_follower_count',
            field=models.PositiveIntegerField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='instagramuser_data',
            name='old_instagram_following_count',
            field=models.PositiveIntegerField(blank=True, null=True),
        ),
    ]
