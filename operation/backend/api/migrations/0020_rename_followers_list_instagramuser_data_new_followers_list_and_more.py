# Generated by Django 5.1.5 on 2025-03-13 12:46

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('api', '0019_alter_instagramuser_data_instagram_follower_count_and_more'),
    ]

    operations = [
        migrations.RenameField(
            model_name='instagramuser_data',
            old_name='followers_list',
            new_name='new_followers_list',
        ),
        migrations.AddField(
            model_name='instagramuser_data',
            name='old_followers_list',
            field=models.JSONField(blank=True, default=list),
        ),
    ]
