package SBEAMS::SolexaTrans::SlimseqProject;
use base qw(Class::AutoClass);
use strict;
use warnings;
use Carp;
use Data::Dumper;

use SBEAMS::SolexaTrans::SlimseqClient;

use vars qw(@AUTO_ATTRIBUTES @CLASS_ATTRIBUTES %DEFAULTS %SYNONYMS);
@AUTO_ATTRIBUTES = qw(project_id project
		      id uri updated_at 
		      lab_group tag_length file_folder name
		      sample_uris lab_group_uri
		      ref_genome restriction_enzyme
		      export_files export_dir export_index
		      lanes lane2sample_id
		      );
@CLASS_ATTRIBUTES = qw();
%DEFAULTS = ();
%SYNONYMS = ();

Class::AutoClass::declare(__PACKAGE__);

sub _init_self {
    my ($self, $class, $args) = @_;
    return unless $class eq __PACKAGE__; # to prevent subclasses from re-running this
}

sub fetch {
    my ($self)=@_;
    my $project_id=$self->project_id or confess "no project_id";

    my $slim_client=SlimseqClient->new;
    my $project=$slim_client->gather_sample_info($project_id);
    $self->project($project);

    foreach my $attr (qw(id updated_at name lab_group tag_length file_folder sample_uris
			 export_index lanes ref_genome restriction_enzyme export_files export_dir
			 lane2sample_id lab_group_uri)) {
	$self->$attr($project->{$attr});
    }

    $self;
}

1;
