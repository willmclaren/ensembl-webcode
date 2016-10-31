=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::ImageConfig::contigviewbottom;

use strict;
use warnings;

use EnsEMBL::Web::Command::UserData::AddFile;

use parent qw(EnsEMBL::Web::ImageConfig);

sub glyphset_tracks {
  ## @override
  ## Adds trackhub tracks before returning the list of tracks
  my $self = shift;

  if (!$self->{'_glyphset_tracks'}) {
    $self->get_node('user_data')->after($_) for grep $_->get_data('trackhub_menu'), $self->tree->nodes;
    $self->SUPER::glyphset_tracks;
  }

  return $self->{'_glyphset_tracks'};
}

sub config_url_params {
  ## @override
  ## Returns list of trackhub related params along with other url params that can change the image config
  my $self = shift;
  return $self->SUPER::config_url_params || (), $self->type, qw(attach trackhub format menu);
}

sub update_from_url {
  ## @override
  my ($self, $params) = @_;

  my $hub             = $self->hub;
  my $session         = $hub->session;
  my $species         = $self->species;
  my $species_defs    = $self->species_defs;
  my @values          = split(/,/, grep($_, delete $params->{'attach'}, delete $params->{$self->type}) || ''); # delete params to avoid doing it again when calling SUPER method

  # if param name is 'trackhub'
  push @values, $params->{'trackhub'} || ();

  # Backwards compatibility
  if ($params->{'format'} && $params->{'format'} eq 'DATAHUB') {
    $params->{'format'} = 'TRACKHUB';
  }

  foreach my $v (@values) {
    my $format = $params->{'format'};
    my ($url, $renderer, $attach);

    if ($v =~ /^url/) {
      $v =~ s/^url://;
      $attach = 1;
      ($url, $renderer) = split /=/, $v;
    }

    if ($attach || $params->{'attach'}) {
      ## Backwards compatibility with 'contigviewbottom=url:http...'-type parameters
      ## as well as new 'attach=http...' parameter
      my $p = uri_unescape($url);

      my $menu_name   = $params->{'menu'};
      my $all_formats = $species_defs->multi_val('DATA_FORMAT_INFO');

      if (!$format) {
        my @path = split(/\./, $p);
        my $ext  = $path[-1] eq 'gz' ? $path[-2] : $path[-1];

        while (my ($name, $info) = each %$all_formats) {
          if ($ext =~ /^$name$/i) {
            $format = $name;
            last;
          }
        }
        if (!$format) {
          # Didn't match format name - now try checking format extensions
          while (my ($name, $info) = each %$all_formats) {
            if ($ext eq $info->{'ext'}) {
              $format = $name;
              last;
            }
          }
        }
      }

      my $style = $all_formats->{lc $format}{'display'} eq 'graph' ? 'wiggle' : $format;
      my $code  = join '_', md5_hex("$species:$p"), $session->session_id;
      my $n;

      if ($menu_name) {
        $n = $menu_name;
      } else {
        $n = $p =~ /\/([^\/]+)\/*$/ ? $1 : 'un-named';
      }

      # Don't add if the URL or menu are the same as an existing track
      my $url_record_data = $session->get_record_data({'type' => 'url', 'code' => $code});
      my $duplicate_record_data = $session->get_record_data({'name' => $n, 'type' => 'url'});
      if (keys %$url_record_data) {
        $session->set_record_data({
          'type'      => 'message',
          'function'  => '_warning',
          'code'      => "duplicate_url_track_$code",
          'message'   => "You have already attached the URL $p. No changes have been made for this data source.",
        });

        next;
      } elsif (%$duplicate_record_data) {
        $session->set_record_data({
          'type'      => 'message',
          'function'  => '_error',
          'code'      => "duplicate_url_track_$n",
          'message'   => qq{Sorry, the menu "$n" is already in use. Please change the value of "menu" in your URL and try again.},
        });

        next;
      }

      # We then have to create a node in the user_config
      my %ensembl_assemblies = %{$species_defs->assembly_lookup};

      if (uc $format eq 'TRACKHUB') {
        my $info;
        ($n, $info) = $self->_add_trackhub($n, $p);
        if ($info->{'error'}) {
          my @errors = @{$info->{'error'} || []};
          $session->set_record_data({
            'type'      => 'message',
            'function'  => '_warning',
            'code'      => 'trackhub:' . md5_hex($p),
            'message'   => "There was a problem attaching trackhub $n: @errors",
          });
        } else {
          my $assemblies = $info->{'genomes'} || {$species => $species_defs->get_config($species, 'ASSEMBLY_VERSION')};

          foreach (keys %$assemblies) {
            my ($data_species, $assembly) = @{$ensembl_assemblies{$_} || []};
            if ($assembly) {
              my $data = $session->set_record_data({
                'type'        => 'url',
                'url'         => $p,
                'species'     => $data_species,
                'code'        => join('_', md5_hex($n . $data_species . $assembly . $p), $session->session_id),
                'name'        => $n,
                'format'      => $format,
                'style'       => $style,
                'assembly'    => $assembly,
              });
            }
          }
        }
      } else {
        ## Either upload or attach the file, as appropriate
        my $command = EnsEMBL::Web::Command::UserData::AddFile->new({'hub' => $hub});
        ## Fake the params that are passed by the upload form
        $hub->param('text', $p);
        $hub->param('format', $format);
        $command->upload_or_attach($renderer);
        ## Discard URL param, as we don't need it once we've uploaded the file,
        ## and it only messes up the page URL later
        $hub->input->delete('url');
      }
      # We have to create a URL upload entry in the session
      my $message  = sprintf('Data has been attached to your display from the following URL: %s', encode_entities($p));
      $session->set_record_data({
        'type'      => 'message',
        'function'  => '_info',
        'code'      => 'url_data:' . md5_hex($p),
        'message'   => $message,
      });
    } else {
      ($url, $renderer) = split /=/, $v;
      $renderer ||= 'normal';
      $self->update_track_renderer($url, $renderer);
    }
  }

  if ($self->is_altered) {
    my $tracks = join(', ', grep $_ ne '1', @{$self->altered});
    $session->set_record_data({
      'type'      => 'message',
      'function'  => '_info',
      'code'      => 'image_config',
      'message'   => "The link you followed has made changes to these tracks: $tracks.",
    });
  }

  return $self->SUPER::update_from_url($params);
}

sub init_cacheable {
  ## @override
  my $self = shift;

  $self->SUPER::init_cacheable(@_);

  $self->set_parameters({
    image_resizeable  => 1,
    bottom_toolbar    => 1,
    sortable_tracks   => 'drag', # allow the user to reorder tracks on the image
    can_trackhubs     => 1,      # allow track hubs
    opt_halfheight    => 0,      # glyphs are half-height [ probably removed when this becomes a track config ]
    opt_lines         => 1,      # draw registry lines
  });

  # First add menus in the order you want them for this display
  $self->create_menus(qw(
    sequence
    marker
    trans_associated
    transcript
    prediction
    lrg
    dna_align_cdna
    dna_align_est
    dna_align_rna
    dna_align_other
    protein_align
    protein_feature
    rnaseq
    ditag
    simple
    genome_attribs
    misc_feature
    variation
    recombination
    somatic
    functional
    multiple_align
    conservation
    pairwise_blastz
    pairwise_tblat
    pairwise_other
    dna_align_compara
    oligo
    repeat
    external_data
    user_data
    decorations
    information
  ));

  my %desc = (
    contig    => 'Track showing underlying assembly contigs.',
    seq       => 'Track showing sequence in both directions. Only displayed at 1Kb and below.',
    codon_seq => 'Track showing 6-frame translation of sequence. Only displayed at 500bp and below.',
    codons    => 'Track indicating locations of start and stop codons in region. Only displayed at 50Kb and below.'
  );

  # Note these tracks get added before the "auto-loaded tracks" get added
  $self->add_tracks('sequence',
    [ 'contig',    'Contigs',             'contig',   { display => 'normal', strand => 'r', description => $desc{'contig'}                                                                }],
    [ 'seq',       'Sequence',            'sequence', { display => 'normal', strand => 'b', description => $desc{'seq'},       colourset => 'seq',      threshold => 1,   depth => 1      }],
    [ 'codon_seq', 'Translated sequence', 'codonseq', { display => 'off',    strand => 'b', description => $desc{'codon_seq'}, colourset => 'codonseq', threshold => 0.5, bump_width => 0 }],
    [ 'codons',    'Start/stop codons',   'codons',   { display => 'off',    strand => 'b', description => $desc{'codons'},    colourset => 'codons',   threshold => 50                   }],
  );

  $self->add_track('decorations', 'gc_plot', '%GC', 'gcplot', { display => 'normal',  strand => 'r', description => 'Shows percentage of Gs & Cs in region', sortable => 1 });

  my $gencode_version = $self->hub->species_defs->GENCODE_VERSION ? $self->hub->species_defs->GENCODE_VERSION : '';
  $self->add_track('transcript', 'gencode', "Basic Gene Annotations from $gencode_version", '_gencode', {
      labelcaption => "Genes (Basic set from $gencode_version)",
      display     => 'off',
      description => 'The GENCODE set is the gene set for human and mouse. GENCODE Basic is a subset of representative transcripts (splice variants).',
      sortable    => 1,
      colours     => $self->species_defs->colour('gene'),
      label_key  => '[biotype]',
      logic_names => ['proj_ensembl',  'proj_ncrna', 'proj_havana_ig_gene', 'havana_ig_gene', 'ensembl_havana_ig_gene', 'proj_ensembl_havana_lincrna', 'proj_havana', 'ensembl', 'mt_genbank_import', 'ensembl_havana_lincrna', 'proj_ensembl_havana_ig_gene', 'ncrna', 'assembly_patch_ensembl', 'ensembl_havana_gene', 'ensembl_lincrna', 'proj_ensembl_havana_gene', 'havana'],
      renderers   =>  [
        'off',                     'Off',
        'gene_nolabel',            'No exon structure without labels',
        'gene_label',              'No exon structure with labels',
        'transcript_nolabel',      'Expanded without labels',
        'transcript_label',        'Expanded with labels',
        'collapsed_nolabel',       'Collapsed without labels',
        'collapsed_label',         'Collapsed with labels',
        'transcript_label_coding', 'Coding transcripts only (in coding genes)',
      ],
    }) if($gencode_version);

  if ($self->species_defs->ALTERNATIVE_ASSEMBLIES) {
    foreach my $alt_assembly (@{$self->species_defs->ALTERNATIVE_ASSEMBLIES}) {
      $self->add_track('misc_feature', "${alt_assembly}_assembly", "$alt_assembly assembly", 'alternative_assembly', {
        display       => 'off',
        strand        => 'f',
        colourset     => 'alternative_assembly',
        description   => "Track indicating $alt_assembly assembly",
        assembly_name => $alt_assembly
      });
    }
  }

  # Add in additional tracks
  $self->load_tracks;
  $self->load_configured_trackhubs;
  $self->load_configured_bigwig;
  $self->load_configured_bigbed;
#  $self->load_configured_bam;

  #switch on some variation tracks by default
  if ($self->species_defs->DEFAULT_VARIATION_TRACKS) {
    while (my ($track, $style) = each (%{$self->species_defs->DEFAULT_VARIATION_TRACKS})) {
      $self->modify_configs([$track], {display => $style});
    }
  }
  elsif ($self->hub->database('variation')) {
    my $tracks = [qw(variation_feature_variation)];
    if ($self->species_defs->databases->{'DATABASE_VARIATION'}{'STRUCTURAL_VARIANT_COUNT'}) {
      push @$tracks, 'variation_feature_structural_smaller';
    }
    $self->modify_configs($tracks, {display => 'compact'});
  }

  # These tracks get added after the "auto-loaded tracks get addded
  if ($self->species_defs->ENSEMBL_MOD) {
    $self->add_track('information', 'mod', '', 'text', {
      name    => 'Message of the day',
      display => 'normal',
      menu    => 'no',
      strand  => 'r',
      text    => $self->species_defs->ENSEMBL_MOD
    });
  }

  $self->add_tracks('information',
    [ 'missing', '', 'text', { display => 'normal', strand => 'r', name => 'Disabled track summary', description => 'Show counts of number of tracks turned off by the user' }],
    [ 'info',    '', 'text', { display => 'normal', strand => 'r', name => 'Information',            description => 'Details of the region shown in the image' }]
  );

  $self->add_tracks('decorations',
    [ 'scalebar',  '', 'scalebar',  { display => 'normal', strand => 'b', name => 'Scale bar', description => 'Shows the scalebar' }],
    [ 'ruler',     '', 'ruler',     { display => 'normal', strand => 'b', name => 'Ruler',     description => 'Shows the length of the region being displayed' }],
    [ 'draggable', '', 'draggable', { display => 'normal', strand => 'b', menu => 'no' }]
  );

  ## LRG track
  if ($self->species_defs->HAS_LRG) {
    $self->add_tracks('lrg',
      [ 'lrg_transcript', 'LRG', '_transcript', {
        display     => 'off', # Switched off by default
        strand      => 'b',
        name        => 'LRG',
        description => 'Transcripts from the <a class="external" href="http://www.lrg-sequence.org">Locus Reference Genomic sequence</a> project.',
        logic_names => [ 'LRG_import' ],
        logic_name  => 'LRG_import',
        colours     => $self->species_defs->colour('gene'),
        label_key   => '[display_label]',
        colour_key  => '[logic_name]',
        zmenu       => 'LRG',
      }]
    );
  }

  ## Switch on multiple alignments defined in MULTI.ini
  my $compara_db      = $self->hub->database('compara');
  if ($compara_db) {
    my $mlss_adaptor    = $compara_db->get_adaptor('MethodLinkSpeciesSet');
    my %alignments      = $self->species_defs->multiX('COMPARA_DEFAULT_ALIGNMENTS');
    my $defaults = $self->hub->species_defs->multi_hash->{'DATABASE_COMPARA'}->{'COMPARA_DEFAULT_ALIGNMENT_IDS'};

    foreach my $default (@$defaults) {
      my ($mlss_id,$species,$method) = @$default;
      $self->modify_configs(
        [ 'alignment_compara_'.$mlss_id.'_constrained' ],
        { display => 'compact' }
      );
    }
  }

  my @feature_sets = ('cisRED', 'VISTA', 'miRanda', 'NestedMICA', 'REDfly CRM', 'REDfly TFBS');

  foreach my $f_set (@feature_sets) {
    $self->modify_configs(
      [ "regulatory_regions_funcgen_$f_set" ],
      { depth => 25, height => 6 }
    );
  }

  ## Regulatory build track now needs to be turned on explicitly
  $self->modify_configs(['regbuild'], {display => 'compact'});
}

sub get_shareable_nodes {
  ## @override
  ## Can share trackhubs too
  my $self = shift;

  my @nodes = $self->SUPER::get_shareable_nodes;

  push @nodes, grep $_->get_data('trackhub_menu'), $self->tree->nodes;

  return @nodes;
}

1;
