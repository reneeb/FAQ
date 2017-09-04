# --
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package var::packagesetup::FAQ;

use strict;
use warnings;

use Kernel::Output::Template::Provider;
use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Cache',
    'Kernel::System::DB',
    'Kernel::System::DynamicField',
    'Kernel::System::DynamicFieldValue',
    'Kernel::System::FAQ',
    'Kernel::System::Group',
    'Kernel::System::LinkObject',
    'Kernel::System::Log',
    'Kernel::System::Stats',
    'Kernel::System::SysConfig',
    'Kernel::System::Valid',
);

=head1 NAME

FAQ.pm - code to execute during package installation

=head1 DESCRIPTION

All functions

=head1 PUBLIC INTERFACE

=head2 new()

create an object

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $CodeObject = $Kernel::OM->Get('var::packagesetup::FAQ');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # Allocate new hash for object.
    my $Self = {};
    bless( $Self, $Type );

    $Kernel::OM->ObjectsDiscard();

    my $SysConfigObject = $Kernel::OM->Get('Kernel::System::SysConfig');

    # Convert XML files to entries in the database.
    if (
        !$SysConfigObject->ConfigurationXML2DB(
            CleanUp => 1,
            Force   => 1,
            UserID  => 1,
        )
        )
    {
        return;
    }

    if (
        !$SysConfigObject->ConfigurationDeploy(
            Comments => $Param{Comments} || "Configuration Rebuild",
            AllSettings  => 1,
            Force        => 1,
            NoValidation => 1,
            UserID       => 1,
        )
        )
    {
        return;
    }

    # Force a reload of ZZZAuto.pm to get the fresh configuration values.
    for my $Module ( sort keys %INC ) {
        if ( $Module =~ m/ZZZAA?uto\.pm$/ ) {
            delete $INC{$Module};
        }
    }

    # Create common objects with fresh default config.
    $Kernel::OM->ObjectsDiscard();

    # The stats object needs a UserID parameter for the constructor.
    # We need to discard any existing stats object before.
    $Kernel::OM->ObjectsDiscard(
        Objects => ['Kernel::System::Stats'],
    );

    # Define UserID parameter for the constructor of the stats object.
    $Kernel::OM->ObjectParamAdd(
        'Kernel::System::Stats' => {
            UserID => 1,
        },
    );

    # Define file prefix.
    $Self->{FilePrefix} = 'FAQ';

    return $Self;
}

=head2 CodeInstall()

run the code install part

    my $Result = $CodeObject->CodeInstall();

=cut

sub CodeInstall {
    my ( $Self, %Param ) = @_;

    # insert the FAQ states
    $Self->_InsertFAQStates();

    # add the group FAQ
    $Self->_GroupAdd(
        Name        => 'faq',
        Description => 'faq database users',
    );

    # add the group faq_admin
    $Self->_GroupAdd(
        Name        => 'faq_admin',
        Description => 'faq admin users',
    );

    # add the group faq_approval
    $Self->_GroupAdd(
        Name        => 'faq_approval',
        Description => 'faq approval users',
    );

    # add the FAQ groups to the category 'Misc'
    $Self->_CategoryGroupSet(
        Category => 'Misc',
        Groups   => [ 'faq', 'faq_admin', 'faq_approval' ],
    );

    # create additional FAQ languages
    $Self->_CreateAditionalFAQLanguages();

    # install stats
    $Kernel::OM->Get('Kernel::System::Stats')->StatsInstall(
        FilePrefix => $Self->{FilePrefix},
        UserID     => 1,
    );

    return 1;
}

=head2 CodeReinstall()

run the code reinstall part

    my $Result = $CodeObject->CodeReinstall();

=cut

sub CodeReinstall {
    my ( $Self, %Param ) = @_;

    # insert the FAQ states
    $Self->_InsertFAQStates();

    # add the group FAQ
    $Self->_GroupAdd(
        Name        => 'faq',
        Description => 'faq database users',
    );

    # add the group faq_admin
    $Self->_GroupAdd(
        Name        => 'faq_admin',
        Description => 'faq admin users',
    );

    # add the group faq_approval
    $Self->_GroupAdd(
        Name        => 'faq_approval',
        Description => 'faq approval users',
    );

    # install stats
    $Kernel::OM->Get('Kernel::System::Stats')->StatsInstall(
        FilePrefix => $Self->{FilePrefix},
        UserID     => 1,
    );

    # create additional FAQ languages
    $Self->_CreateAditionalFAQLanguages();

    return 1;
}

=head2 CodeUpgrade()

run the code upgrade part

    my $Result = $CodeObject->CodeUpgrade();

=cut

sub CodeUpgrade {
    my ( $Self, %Param ) = @_;

    # install stats
    $Kernel::OM->Get('Kernel::System::Stats')->StatsInstall(
        FilePrefix => $Self->{FilePrefix},
        UserID     => 1,
    );

    # create additional FAQ languages
    $Self->_CreateAditionalFAQLanguages();

    # delete the FAQ cache (to avoid old data from previous FAQ modules)
    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
        Type => 'FAQ',
    );

    return 1;
}

=head2 CodeUpgradeSpecial()

run special code upgrade part

    my $Result = $CodeObject->CodeUpgradeSpecial();

=cut

sub CodeUpgradeSpecial {
    my ( $Self, %Param ) = @_;

    # convert \n to <br> for existing articles
    $Self->_ConvertNewlines();

    # start normal code upgrade
    $Self->CodeUpgrade();

    return 1;
}

=head2 CodeUninstall()

run the code uninstall part

    my $Result = $CodeObject->CodeUninstall();

=cut

sub CodeUninstall {
    my ( $Self, %Param ) = @_;

    # remove Dynamic Fields and its values
    $Self->_DynamicFieldsDelete();

    # deactivate the group FAQ
    $Self->_GroupDeactivate(
        Name => 'faq',
    );

    # deactivate the group faq_admin
    $Self->_GroupDeactivate(
        Name => 'faq_admin',
    );

    # deactivate the group faq_approval
    $Self->_GroupDeactivate(
        Name => 'faq_approval',
    );

    # uninstall stats
    $Kernel::OM->Get('Kernel::System::Stats')->StatsUninstall(
        FilePrefix => $Self->{FilePrefix},
        UserID     => 1,
    );

    # delete all links with FAQ articles
    $Self->_LinkDelete();

    return 1;
}

=head2 _InsertFAQStates()

inserts needed FAQ states into table

    my $Result = $CodeObject->_InsertFAQStates();

=cut

sub _InsertFAQStates {
    my ( $Self, %Param ) = @_;

    # define faq_state_types => faq_states
    my %State = (
        'internal' => 'internal (agent)',
        'external' => 'external (customer)',
        'public'   => 'public (all)',
    );

    # get FAQ object
    my $FAQObject = $Kernel::OM->Get('Kernel::System::FAQ');

    for my $Type ( sort keys %State ) {

        # get the state type
        my $StateTypeRef = $FAQObject->StateTypeGet(
            Name   => $Type,
            UserID => 1,
        );

        # add the state
        $FAQObject->StateAdd(
            Name   => $State{$Type},
            TypeID => $StateTypeRef->{StateID},
            UserID => 1,
        );
    }

    return 1;
}

=head2 _ConvertNewlines()

coverts all \n into <br> for Fields 1-6 in all existing FAQ articles

    my $Result = $CodeObject->_ConvertNewlines();

=cut

sub _ConvertNewlines {
    my ( $Self, %Param ) = @_;

    # only convert \n to <br> if HTML view is enabled
    return if !$Kernel::OM->Get('Kernel::Config')->Get('FAQ::Item::HTML');

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # get all FAQ IDs
    my @ItemIDs;
    $DBObject->Prepare(
        SQL => "SELECT id FROM faq_item",
    );
    while ( my @Row = $DBObject->FetchrowArray() ) {
        push( @ItemIDs, $Row[0] );
    }

    # get FAQ object
    my $FAQObject = $Kernel::OM->Get('Kernel::System::FAQ');

    ID:
    for my $ItemID (@ItemIDs) {

        # get FAQ data
        my %FAQ = $FAQObject->FAQGet(
            ItemID     => $ItemID,
            ItemFields => 1,
            UserID     => 1,
        );

        # get FAQ article fields 1-6
        my $FoundNewline;
        KEY:
        for my $Key (qw (Field1 Field2 Field3 Field4 Field5 Field6)) {
            next KEY if !$FAQ{$Key};

            # replace \n with <br>
            $FAQ{$Key} =~ s/\n/<br\/>\n/g;

            $FoundNewline = 1;
        }
        next ID if !$FoundNewline;

        # update FAQ data
        $FAQObject->FAQUpdate(
            %FAQ,
            UserID => 1,
        );
    }

    return 1;
}

=head2 _GroupAdd()

add a group

    my $Result = $CodeObject->_GroupAdd(
        Name        => 'the-group-name',
        Description => 'The group description.',
    );

=cut

sub _GroupAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Name Description)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );

            return;
        }
    }

    # get valid list
    my %ValidList = $Kernel::OM->Get('Kernel::System::Valid')->ValidList(
        UserID => 1,
    );
    my %ValidListReverse = reverse %ValidList;

    # get group object
    my $GroupObject = $Kernel::OM->Get('Kernel::System::Group');

    # get list of all groups
    my %GroupList = $GroupObject->GroupList();

    # reverse the group list for easier lookup
    my %GroupListReverse = reverse %GroupList;

    # check if group already exists
    my $GroupID = $GroupListReverse{ $Param{Name} };

    # reactivate the group
    if ($GroupID) {

        # get current group data
        my %GroupData = $GroupObject->GroupGet(
            ID     => $GroupID,
            UserID => 1,
        );

        # reactivate group
        $GroupObject->GroupUpdate(
            %GroupData,
            ValidID => $ValidListReverse{valid},
            UserID  => 1,
        );

        return 1;
    }

    # add the group
    else {
        return if !$GroupObject->GroupAdd(
            Name    => $Param{Name},
            Comment => $Param{Description},
            ValidID => $ValidListReverse{valid},
            UserID  => 1,
        );
    }

    # lookup the new group id
    my $NewGroupID = $GroupObject->GroupLookup(
        Group  => $Param{Name},
        UserID => 1,
    );

    # add user root to the group
    $GroupObject->GroupMemberAdd(
        GID        => $NewGroupID,
        UID        => 1,
        Permission => {
            ro        => 1,
            move_into => 1,
            create    => 1,
            owner     => 1,
            priority  => 1,
            rw        => 1,
        },
        UserID => 1,
    );

    return 1;
}

=head2 _GroupDeactivate()

deactivate a group

    my $Result = $CodeObject->_GroupDeactivate(
        Name => 'the-group-name',
    );

=cut

sub _GroupDeactivate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Name} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need Name!',
        );

        return;
    }

    # get group object
    my $GroupObject = $Kernel::OM->Get('Kernel::System::Group');

    # lookup group id
    my $GroupID = $GroupObject->GroupLookup(
        Group => $Param{Name},
    );

    return if !$GroupID;

    # get valid list
    my %ValidList = $Kernel::OM->Get('Kernel::System::Valid')->ValidList(
        UserID => 1,
    );
    my %ValidListReverse = reverse %ValidList;

    # get current group data
    my %GroupData = $GroupObject->GroupGet(
        ID     => $GroupID,
        UserID => 1,
    );

    # deactivate group
    $GroupObject->GroupUpdate(
        %GroupData,
        ValidID => $ValidListReverse{invalid},
        UserID  => 1,
    );

    return 1;
}

=head2 _LinkDelete()

delete all existing links to FAQ articles

    my $Result = $CodeObject->_LinkDelete();

=cut

sub _LinkDelete {
    my ( $Self, %Param ) = @_;

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # get all FAQ article ids
    my @ItemIDs = ();
    $DBObject->Prepare(
        SQL => 'SELECT id FROM faq_item'
    );
    while ( my @Row = $DBObject->FetchrowArray() ) {
        push @ItemIDs, $Row[0];
    }
    return if !@ItemIDs;

    # delete the FAQ article links
    for my $ItemID (@ItemIDs) {
        $Kernel::OM->Get('Kernel::System::LinkObject')->LinkDeleteAll(
            Object => 'FAQ',
            Key    => $ItemID,
            UserID => 1,
        );
    }

    return 1;
}

=head2 _CreateAditionalFAQLanguages()

creates additional FAQ languages for system default language and user language

    my $Result = $CodeObject->_CreateAditionalFAQLanguages();

=cut

sub _CreateAditionalFAQLanguages {
    my ( $Self, %Param ) = @_;

    # get system default language
    my $Language = $Kernel::OM->Get('Kernel::Config')->Get('DefaultLanguage');
    if ($Language) {

        # get FAQ object
        my $FAQObject = $Kernel::OM->Get('Kernel::System::FAQ');

        # get current FAQ languages
        my %CurrentLanguages = $FAQObject->LanguageList(
            UserID => 1,
        );

        # use reverse hash for easy lookup
        my %ReverseLanguages = reverse %CurrentLanguages;

        # check if language is already defined
        if ( !$ReverseLanguages{$Language} ) {

            # add language
            my $Success = $FAQObject->LanguageAdd(
                Name   => $Language,
                UserID => 1,
            );
        }
    }
    return 1;
}

=head2 _CategoryGroupSet()

Adds the given group permissions to the given category.

    my $Result = $CodeObject->_CategoryGroupSet(
        Category => 'Misc',
        Groups   => [ 'faq', 'faq-admin', 'faq_approval' ],
    );

=cut

sub _CategoryGroupSet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Category Groups)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );

            return;
        }
    }

    # check needed stuff
    if ( ref $Param{Groups} ne 'ARRAY' ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Groups must be an array reference!",
        );

        return;
    }

    # get FAQ object
    my $FAQObject = $Kernel::OM->Get('Kernel::System::FAQ');

    # get all categories and their ids
    my $CategoryTree = $FAQObject->CategoryTreeList(
        Valid  => 1,
        UserID => 1,
    );

    # create lookup hash for the category id
    my %FAQ2ID = reverse %{$CategoryTree};

    # lookup the category id
    my $CategoryID = $FAQ2ID{ $Param{Category} };

    # lookup the group ids
    my @GroupIDs;
    for my $Group ( @{ $Param{Groups} } ) {
        my $GroupID = $Kernel::OM->Get('Kernel::System::Group')->GroupLookup(
            Group => $Group,
        );
        push @GroupIDs, $GroupID;
    }

    # set category group
    $FAQObject->SetCategoryGroup(
        CategoryID => $CategoryID,
        GroupIDs   => \@GroupIDs,
        UserID     => 1,
    );

    return 1;
}

=head2 _DynamicFieldsDelete()

delete all existing dynamic fields for FAQ

    my $Result = $CodeObject->_DynamicFieldsDelete();

=cut

sub _DynamicFieldsDelete {
    my ( $Self, %Param ) = @_;

    my $DynamicFieldObject      = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $DynamicFieldValueObject = $Kernel::OM->Get('Kernel::System::DynamicFieldValue');

    # get the list of FAQ dynamic fields (valid and invalid ones)
    my $DynamicFieldList = $DynamicFieldObject->DynamicFieldListGet(
        Valid      => 0,
        ObjectType => ['FAQ'],
    );

    # delete the dynamic fields
    DYNAMICFIELD:
    for my $DynamicField ( @{$DynamicFieldList} ) {

        # delete all field values
        my $ValuesDeleteSuccess = $DynamicFieldValueObject->AllValuesDelete(
            FieldID => $DynamicField->{ID},
            UserID  => 1,
        );

        # values could be deleted
        if ($ValuesDeleteSuccess) {

            # delete field
            my $Success = $DynamicFieldObject->DynamicFieldDelete(
                ID     => $DynamicField->{ID},
                UserID => 1,
            );

            # check error
            if ( !$Success ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => "Could not delete dynamic field '$DynamicField->{Name}'!",
                );
            }
        }

        # values could not be deleted
        else {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Could not delete values for dynamic field '$DynamicField->{Name}'!",
            );
        }
    }

    return 1;
}

1;

=head1 TERMS AND CONDITIONS

This software is part of the OTRS project (L<http://otrs.org/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut
