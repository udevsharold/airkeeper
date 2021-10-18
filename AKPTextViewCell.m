//    Copyright (c) 2021 udevs
//
//    This program is free software: you can redistribute it and/or modify
//    it under the terms of the GNU General Public License as published by
//    the Free Software Foundation, version 3.
//
//    This program is distributed in the hope that it will be useful, but
//    WITHOUT ANY WARRANTY; without even the implied warranty of
//    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
//    General Public License for more details.
//
//    You should have received a copy of the GNU General Public License
//    along with this program. If not, see <http://www.gnu.org/licenses/>.

#import "AKPTextViewCell.h"

@implementation AKPTextViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString*)reuseIdentifier specifier:(PSSpecifier*)specifier{
	
	if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier specifier:specifier]){
		
		_textView = [[UITextView alloc] initWithFrame:CGRectZero];
		_textView.delegate = self;
		_textView.autocorrectionType = UITextAutocorrectionTypeNo;
		_textView.autocapitalizationType = UITextAutocapitalizationTypeNone;
		
		_textView.editable = [[self.specifier propertyForKey:@"editable"] ?: @YES boolValue];
		_textView.textColor = _textView.editable ? [UITextView _defaultTextColor] : [UIColor systemGrayColor];

		_textView.translatesAutoresizingMaskIntoConstraints = NO;
		
		NSLayoutConstraint *leadConstraint = [NSLayoutConstraint constraintWithItem:self.contentView attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:_textView attribute:NSLayoutAttributeLeading multiplier:1.0 constant:-8.0];
		NSLayoutConstraint *trailConstraint = [NSLayoutConstraint constraintWithItem:self.contentView attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:_textView attribute:NSLayoutAttributeTrailing multiplier:1.0 constant:8.0];
		
		NSLayoutConstraint *topConstraint = [NSLayoutConstraint constraintWithItem:self.contentView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:_textView attribute:NSLayoutAttributeTop multiplier:1.0 constant:-8.0];
		NSLayoutConstraint *bottomConstraint = [NSLayoutConstraint constraintWithItem:self.contentView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:_textView attribute:NSLayoutAttributeBottom multiplier:1.0 constant:8.0];
		
		[self.contentView addSubview:_textView];

		[NSLayoutConstraint activateConstraints:@[leadConstraint, trailConstraint, topConstraint, bottomConstraint]];
		
	}
	return self;
}

-(void)refreshCellContentsWithSpecifier:(PSSpecifier*)specifier{
	[self updateTextAttributes];
	[super refreshCellContentsWithSpecifier:specifier];
}

-(void)setValue:(id)value{
	if ([value isKindOfClass:[NSString class]]){
		_textView.text = value;
	}
}

-(void)textViewDidEndEditing:(UITextView *)textView{
	if ([self.specifier respondsToSelector:@selector(performSetterWithValue:)]){
		[self.specifier performSetterWithValue:textView.text];
	}
}

-(void)textViewDidChange:(UITextView *)textView{
	if ([self.specifier respondsToSelector:@selector(performSetterWithValue:)]){
		[self.specifier performSetterWithValue:textView.text];
	}
}

-(void)updateTextAttributes{
	_textView.editable = [[self.specifier propertyForKey:@"editable"] ?: @YES boolValue];
	if ([UITextView respondsToSelector:@selector(_defaultTextColor)]){
		_textView.textColor = _textView.editable ? [UITextView _defaultTextColor] : [UIColor systemGrayColor];
	}else{
		_textView.textColor = _textView.editable ? [UIColor blackColor] : [UIColor systemGrayColor];
	}
}

-(void)prepareForReuse{
	[super prepareForReuse];
	_textView.text = nil;
	[self updateTextAttributes];
}

@end
