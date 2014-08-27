=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::Regulation::Buttons;

use strict;

use base qw(EnsEMBL::Web::Component::Regulation);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
  $self->has_image(0);
}

sub content {
  my $self         = shift;

  $self->cell_line_button('regulation_view');
  $self->evidence_button;
  $self->renderer_button;
  $self->advanced_button('featuresbycellline');

  return '';
}

sub button_style {
  my ($self) = @_;

  return {
    class => 'regulation_buttons',
  };
}

1;
