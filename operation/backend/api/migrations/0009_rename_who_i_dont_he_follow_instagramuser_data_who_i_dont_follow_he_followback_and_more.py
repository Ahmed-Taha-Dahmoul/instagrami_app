# Generated by Django 5.1.5 on 2025-02-22 01:47

from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ('api', '0008_instagramuser_data_who_i_dont_he_follow_and_more'),
    ]

    operations = [
        migrations.RenameField(
            model_name='instagramuser_data',
            old_name='who_i_dont_he_follow',
            new_name='who_i_dont_follow_he_followback',
        ),
        migrations.RenameField(
            model_name='instagramuser_data',
            old_name='who_i_follow_he_dont',
            new_name='who_i_follow_he_dont_followback',
        ),
    ]
